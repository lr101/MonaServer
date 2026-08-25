package handler

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"mime/quotedprintable"
	"net"
	stdmail "net/mail"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/lrprojects/monaserver/internal/config"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

type smtpMessage struct {
	recipient string
	body      string
}

func TestCreateReportRejectsUnknownUser(t *testing.T) {
	authHandler, _ := setupAuthServicer(t)
	mail := service.NewEmail(&config.Config{MailUsername: "reports@example.com"}, nil)
	servicer := NewReportServicer(mail, authHandler.q)
	resp, err := servicer.CreateReport(context.Background(), genserver.ReportDto{
		UserId: uuid.NewString(), Report: "spam", Message: "details",
	})
	if err != nil {
		t.Fatalf("create report: %v", err)
	}
	if resp.Code != 404 {
		t.Fatalf("report status = %d, want 404", resp.Code)
	}
}

func startSMTPRecorder(t *testing.T) (string, int, <-chan smtpMessage) {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}
	t.Cleanup(func() { _ = listener.Close() })
	host, portText, err := net.SplitHostPort(listener.Addr().String())
	if err != nil {
		t.Fatalf("split listener address: %v", err)
	}
	port, err := strconv.Atoi(portText)
	if err != nil {
		t.Fatalf("parse listener port: %v", err)
	}
	received := make(chan smtpMessage, 1)
	go func() {
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		reader := bufio.NewReader(conn)
		writer := bufio.NewWriter(conn)
		write := func(line string) {
			_, _ = writer.WriteString(line + "\r\n")
			_ = writer.Flush()
		}
		write("220 localhost ESMTP")
		var recipient string
		var data strings.Builder
		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				return
			}
			command := strings.TrimSpace(line)
			switch {
			case strings.HasPrefix(command, "EHLO"), strings.HasPrefix(command, "HELO"):
				_, _ = writer.WriteString("250-localhost\r\n250 AUTH PLAIN\r\n")
				_ = writer.Flush()
			case strings.HasPrefix(command, "AUTH"):
				write("235 2.7.0 Authentication successful")
			case strings.HasPrefix(command, "MAIL FROM"):
				write("250 2.1.0 OK")
			case strings.HasPrefix(command, "RCPT TO"):
				recipient = strings.Trim(command[len("RCPT TO:"):], "<>")
				write("250 2.1.5 OK")
			case command == "DATA":
				write("354 End data with <CR><LF>.<CR><LF>")
				for {
					dataLine, err := reader.ReadString('\n')
					if err != nil {
						return
					}
					if strings.TrimSpace(dataLine) == "." {
						break
					}
					data.WriteString(dataLine)
				}
				write("250 2.0.0 queued")
				received <- smtpMessage{recipient: recipient, body: data.String()}
			case command == "QUIT":
				write("221 2.0.0 bye")
				return
			default:
				write("250 OK")
			}
		}
	}()
	return host, port, received
}

func TestCreateReportSendsMailToConfiguredInbox(t *testing.T) {
	host, port, received := startSMTPRecorder(t)
	mail := service.NewEmail(&config.Config{
		MailHost: host, MailPort: port, MailUsername: "reports@example.com",
		MailPassword: "password", MailFrom: "server@example.com",
	}, nil)
	servicer := NewReportServicer(mail, nil)
	resp, err := servicer.CreateReport(context.Background(), genserver.ReportDto{
		UserId: "00000000-0000-0000-0000-000000000001",
		Report: "spam", Message: "details",
	})
	if err != nil {
		t.Fatalf("create report: %v", err)
	}
	if resp.Code != 200 {
		t.Fatalf("report status = %d, want 200, body = %#v", resp.Code, resp.Body)
	}
	select {
	case message := <-received:
		if message.recipient != "reports@example.com" {
			t.Fatalf("recipient = %q, want reports@example.com", message.recipient)
		}
		parsed, err := stdmail.ReadMessage(strings.NewReader(message.body))
		if err != nil {
			t.Fatalf("parse report email: %v", err)
		}
		decoded, err := io.ReadAll(quotedprintable.NewReader(parsed.Body))
		if err != nil {
			t.Fatalf("decode report email: %v", err)
		}
		if !strings.Contains(string(decoded), "spam") || !strings.Contains(string(decoded), "details") {
			t.Fatalf("report body does not contain report details: %s", decoded)
		}
	case <-time.After(time.Second):
		t.Fatal(fmt.Sprintf("no report email received within %s", time.Second))
	}
}
