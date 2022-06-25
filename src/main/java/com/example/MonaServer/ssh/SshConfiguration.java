package com.example.MonaServer.ssh;

import com.jcraft.jsch.JSch;
import com.jcraft.jsch.Session;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.web.servlet.ServletContextInitializer;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.PrintWriter;

@Component
public class SshConfiguration implements ServletContextInitializer {


    public SshConfiguration() {
        try {
            if(System.getenv("SSH_ENABLED")!=null){
                JSch jsch = new JSch();
                File file = getKeyFile();
                jsch.addIdentity(file.getAbsolutePath());
                Session session = jsch.getSession(System.getenv("SSH_F_USER"),System.getenv("SSH_F_IP"),Integer.parseInt(System.getenv("SSH_F_PORT")));
                session.setConfig("StrictHostKeyChecking", "no");
                session.connect();
                session.setPortForwardingL(System.getenv("SSH_FROM_IP"),Integer.parseInt(System.getenv("SSH_FROM_PORT")) ,System.getenv("SSH_TO_HOST") ,Integer.parseInt(System.getenv("SSH_TO_PORT")) );
                System.out.println("SSH connection successful");
            }

        } catch (Exception e) {
            System.out.println("ssh settings is failed. skip!" + e);
        }
    }
    @Override
    public void onStartup(ServletContext servletContext) throws ServletException {
    }

    private File getKeyFile() throws FileNotFoundException {
        File file = new File("privateKey");
        String key = System.getenv("SSH_F_KEY").substring(31);
        key = key.substring(0, key.length() - 29).replaceAll(" ", "\n");
        key = "-----BEGIN RSA PRIVATE KEY-----" + key + "-----END RSA PRIVATE KEY-----";
        PrintWriter out = new PrintWriter(file.getAbsolutePath());
        out.println(key);
        out.close();
        file.deleteOnExit();
        return file;
    }
}
