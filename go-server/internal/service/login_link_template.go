package service

import (
	"html"
	"net/http"
	"regexp"
	"strings"

	"github.com/lrprojects/monaserver/internal/apperrors"
)

const LoginLinkAppName = "Stick-It"

const (
	maxLoginLinkTemplateUsernameBytes = 255 * 4 // users.username is varchar(255), and PostgreSQL permits 4-byte UTF-8 runes.
	maxLoginLinkTemplateEmailBytes    = 320
	maxLoginLinkTemplateURLBytes      = MaxEmailLoginCallbackURLBytes + len("?token=") + 43
	loginCodeBytes                    = 6
)

var (
	ErrInvalidLoginLinkTemplate = apperrors.New(http.StatusBadRequest, "invalid login email template")
	loginLinkPlaceholder        = regexp.MustCompile(`{{\s*([a-z_]+)\s*}}`)
)

// LoginLinkEmailTemplate contains plain-text content. The renderer escapes
// variable values and creates the HTML version itself, so campaign editors
// cannot inject arbitrary markup into security emails.
type LoginLinkEmailTemplate struct {
	Subject string
	Body    string
}

type loginLinkTemplateValues struct {
	Username  string
	Email     string
	LoginLink string
	LoginCode string
	ExpiresIn string
	AppName   string
}

func validateLoginLinkEmailTemplate(value *LoginLinkEmailTemplate) error {
	if value == nil {
		return nil
	}
	if !nonEmptyText(value.Subject, MaxCampaignSubjectBytes) || !nonEmptyText(value.Body, MaxCampaignBodyBytes) ||
		!actionTextValid(value.Subject, MaxCampaignSubjectBytes, false) || !actionTextValid(value.Body, MaxCampaignBodyBytes, true) {
		return ErrInvalidLoginLinkTemplate
	}
	if !validLoginLinkTemplateText(value.Subject, false) || !validLoginLinkTemplateText(value.Body, true) {
		return ErrInvalidLoginLinkTemplate
	}
	if templateWorstCaseBytes(value.Subject, false) > MaxEmailSubjectBytes ||
		templateWorstCaseBytes(value.Body, false) > MaxEmailTextBytes ||
		templateWorstCaseBytes(value.Body, true) > MaxEmailHTMLBytes {
		return ErrInvalidLoginLinkTemplate
	}
	return nil
}

func templateWorstCaseBytes(source string, htmlMode bool) int {
	size := 0
	last := 0
	for _, location := range loginLinkPlaceholder.FindAllStringSubmatchIndex(source, -1) {
		static := source[last:location[0]]
		if htmlMode {
			size += len(html.EscapeString(static)) + 4*strings.Count(static, "\n")
		} else {
			size += len(static)
		}
		name := source[location[2]:location[3]]
		size += loginLinkTemplateValueWorstCaseBytes(name, htmlMode)
		last = location[1]
	}
	remaining := source[last:]
	if htmlMode {
		size += len(html.EscapeString(remaining)) + 4*strings.Count(remaining, "\n")
	} else {
		size += len(remaining)
	}
	return size
}

func loginLinkTemplateValueWorstCaseBytes(name string, htmlMode bool) int {
	maximum := 0
	switch name {
	case "username":
		maximum = maxLoginLinkTemplateUsernameBytes
	case "email":
		maximum = maxLoginLinkTemplateEmailBytes
	case "login_link":
		if htmlMode {
			return len(`<a href="">Sign in</a>`) + 6*maxLoginLinkTemplateURLBytes
		}
		return maxLoginLinkTemplateURLBytes
	case "login_code":
		maximum = loginCodeBytes
	case "expires_in":
		maximum = len("24 hours")
	case "app_name":
		maximum = len(LoginLinkAppName)
	}
	if htmlMode {
		return maximum * 6 // html.EscapeString expands one byte to at most six.
	}
	return maximum
}

func validLoginLinkTemplateText(value string, allowLoginLink bool) bool {
	matches := loginLinkPlaceholder.FindAllStringSubmatch(value, -1)
	withoutPlaceholders := loginLinkPlaceholder.ReplaceAllString(value, "")
	if strings.Contains(withoutPlaceholders, "{{") || strings.Contains(withoutPlaceholders, "}}") {
		return false
	}
	allowed := map[string]bool{"username": true, "email": true, "expires_in": true, "app_name": true}
	if allowLoginLink {
		allowed["login_link"] = true
		allowed["login_code"] = true
	}
	hasLoginLink := false
	for _, match := range matches {
		if !allowed[match[1]] {
			return false
		}
		hasLoginLink = hasLoginLink || match[1] == "login_link"
	}
	if allowLoginLink {
		return hasLoginLink
	}
	return true
}

func hasLoginLinkPlaceholder(source, name string) bool {
	for _, match := range loginLinkPlaceholder.FindAllStringSubmatch(source, -1) {
		if match[1] == name {
			return true
		}
	}
	return false
}

func renderLoginLinkEmailContent(templateValue *LoginLinkEmailTemplate, username, to, loginURL, loginCode, expiresIn string) (string, string, string, error) {
	body := templateValue.Body
	if !hasLoginLinkPlaceholder(body, "login_code") {
		body = "Sign-in code: {{login_code}}\n\n" + body
	}
	values := loginLinkTemplateValues{
		Username: username, Email: to, LoginLink: loginURL, LoginCode: loginCode,
		ExpiresIn: expiresIn, AppName: LoginLinkAppName,
	}
	subject := renderLoginLinkTemplate(templateValue.Subject, values, false, false)
	textBody := renderLoginLinkTemplate(body, values, false, false)
	htmlBody := loginLinkEmailShell("Sign in to Stick-It", renderLoginLinkTemplate(body, values, true, true))
	if _, err := RenderEmail(EmailContent{To: to, Subject: subject, Body: textBody, HTML: htmlBody}); err != nil {
		return "", "", "", ErrInvalidLoginLinkTemplate
	}
	return subject, textBody, htmlBody, nil
}

func renderLoginLinkTemplate(source string, values loginLinkTemplateValues, htmlMode, linkedLoginURL bool) string {
	var output strings.Builder
	last := 0
	for _, location := range loginLinkPlaceholder.FindAllStringSubmatchIndex(source, -1) {
		static := source[last:location[0]]
		if htmlMode {
			static = strings.ReplaceAll(html.EscapeString(static), "\n", "<br>\n")
		}
		output.WriteString(static)

		name := source[location[2]:location[3]]
		value := loginLinkTemplateValue(name, values)
		if htmlMode {
			if name == "login_link" && linkedLoginURL {
				output.WriteString(`<a href="` + html.EscapeString(value) + `">Sign in</a>`)
			} else if name == "login_code" {
				output.WriteString(`<span style="font-size:20px;font-weight:700;color:` + brandOrangeForeground + `">` + html.EscapeString(value) + `</span>`)
			} else {
				output.WriteString(html.EscapeString(value))
			}
		} else {
			output.WriteString(value)
		}
		last = location[1]
	}
	remaining := source[last:]
	if htmlMode {
		remaining = strings.ReplaceAll(html.EscapeString(remaining), "\n", "<br>\n")
	}
	output.WriteString(remaining)
	return output.String()
}

func loginLinkTemplateValue(name string, values loginLinkTemplateValues) string {
	switch name {
	case "username":
		return values.Username
	case "email":
		return values.Email
	case "login_link":
		return values.LoginLink
	case "login_code":
		return values.LoginCode
	case "expires_in":
		return values.ExpiresIn
	case "app_name":
		return values.AppName
	default:
		return ""
	}
}
