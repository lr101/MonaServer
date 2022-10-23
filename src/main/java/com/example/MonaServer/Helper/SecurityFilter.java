package com.example.MonaServer.Helper;

import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.NoSuchElementException;
import java.util.Random;

public class SecurityFilter {

    private final String principalRequestValueAdmin = System.getenv("AUTH_TOKEN_ADMIN");

    public boolean checkUser(String username) {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
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

    public static String generateAlphabeticRandomString() {
        int leftLimit = 97; // letter 'a'
        int rightLimit = 122; // letter 'z'
        int targetStringLength = 50;
        Random random = new Random();

        return random.ints(leftLimit, rightLimit + 1)
                .limit(targetStringLength)
                .collect(StringBuilder::new, StringBuilder::appendCodePoint, StringBuilder::append)
                .toString();
    }

}
