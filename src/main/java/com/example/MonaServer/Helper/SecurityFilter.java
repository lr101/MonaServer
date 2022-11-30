package com.example.MonaServer.Helper;

import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Repository.GroupRepo;
import com.example.MonaServer.Repository.PinRepo;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.List;
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

    public String checkUserInGroupThrowsException(Group group) {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (tokenUser.equals(principalRequestValueAdmin)) return tokenUser;
        if (group.getMembers().stream().noneMatch(e -> e.getUsername().equals(tokenUser))) throw new SecurityException("Access denied for this token. User ist not a member of group");
        return tokenUser;
    }

    public void checkPinIsInGroupOfUserThrowsException(Group group, Pin pin) {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (group.getMembers().stream().noneMatch(e -> e.getUsername().equals(tokenUser)) && group.getPins().contains(pin)) {
            throw new SecurityException("Access denied for this token. The user is not a member of its group");
        }
    }

    public void checkIfUserIsInPrivateGroup(Group group) {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (group.getVisibility() != 0 && group.getMembers().stream().noneMatch(e -> e.getUsername().equals(tokenUser))) {
            throw new SecurityException("Access denied for this token. The user is not a member of this private group");
        }
    }

    public void checkUserIsPinCreator(Pin pin) {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (!pin.getUser().getUsername().equals(tokenUser) && !(tokenUser.equals(principalRequestValueAdmin))) {
            throw new SecurityException("Access denied for this token. Username has no edit rights for this pin");
        }
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
