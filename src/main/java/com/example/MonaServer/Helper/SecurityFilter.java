package com.example.MonaServer.Helper;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.context.SecurityContextHolder;

public class SecurityFilter {

    @Value("${AUTH_TOKEN_ADMIN}")
    private String principalRequestValueAdmin;

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
}
