package com.example.MonaServer.Helper;

import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.User;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.NoSuchElementException;
import java.util.Random;
import java.util.Set;

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

    public void checkUserInGroupThrowsException(Group group) {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (group.getMembers().stream().noneMatch(e -> e.getUsername().equals(tokenUser)) || !tokenUser.equals(principalRequestValueAdmin)) throw new SecurityException("Access denied for this token. User ist not a member of group");
    }


    public void checkUserAdminInGroupThrowsException(Group group) {
        if (!checkUser(group.getGroupAdmin().getUsername())) throw new SecurityException("Access denied for this token. User ist not a member of group");
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

    public static String generateAlphabeticRandomString(int targetStringLength) {
        int leftLimit = 97; // letter 'a'
        int rightLimit = 122; // letter 'z'
        Random random = new Random();

        return random.ints(leftLimit, rightLimit + 1)
                .limit(targetStringLength)
                .collect(StringBuilder::new, StringBuilder::appendCodePoint, StringBuilder::append)
                .toString();
    }

}
