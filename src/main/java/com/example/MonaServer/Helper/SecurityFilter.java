package com.example.MonaServer.Helper;

import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.util.NoSuchElementException;

@Service
public class SecurityFilter {

    private @Value("${AUTH_TOKEN_ADMIN}") String principalRequestValueAdmin;

    public boolean checkUser(String username) {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        System.out.println(tokenUser + " " + username + " " + principalRequestValueAdmin);
        return tokenUser.equals(username) || tokenUser.equals(principalRequestValueAdmin);
    }

    public boolean checkAdminOnly() {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        return tokenUser.equals(principalRequestValueAdmin);
    }

    public void checkUserThrowsException(String username) {
        if (!checkUser(username)) throw new SecurityException("Access denied for this token. Username not valid.");
    }

    public void checkAdminOnlyThrowsException() {
        if (!checkAdminOnly()) throw new SecurityException("Access denied for this token. This is not an admin token");
    }

    public void checkJsonForValues(ObjectNode json, String[] values) {
        for (String value : values) {
            if (!json.has(value)) throw new NoSuchElementException("Error: Field " + value +" was not given in request");
        }
    }
}
