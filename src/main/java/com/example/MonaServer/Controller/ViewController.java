package com.example.MonaServer.Controller;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Repository.UserRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import org.springframework.web.servlet.view.RedirectView;

import java.io.IOException;
import java.io.InputStream;
import java.util.List;


@Controller
public class ViewController {

    @Autowired
    UserRepo userRepo;

    @GetMapping("/public/privacy-policy")
    public String privacyPolicy() {
        return "privacy-policy";
    }

    @GetMapping("/public/agb")
    public String agb() {
        return "agb";
    }

    @GetMapping("/public/projects")
    public String website() {
        return "website";
    }

    @GetMapping("/public/projects/contact")
    public String contact() {
        return "Kontakt";
    }

    @GetMapping("/public/projects/about")
    public String about() {
        return "About";
    }

    @GetMapping("/public/web-app")
    public String webApp() {
        return "index";
    }

    @GetMapping("/")
    public RedirectView redirectWithUsingRedirectView(
            RedirectAttributes attributes) {
        return new RedirectView("public/web-app");
    }

    @GetMapping("/public/recover/{url}")
    public String recoverPassword(@PathVariable("url") String url, Model model) {
        List<User> users = userRepo.getUsersWithUrl(url);
        if (users.size() == 1) {
            model.addAttribute("username", users.get(0).getUsername());
            model.addAttribute("token", users.get(0).getToken());
            return "recover";
        } else {
            throw new IllegalArgumentException("ERROR: This reset url does not exist");
        }
    }


}
