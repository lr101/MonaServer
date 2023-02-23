package com.example.MonaServer.Controller;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.JWTUtil;
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

    /**
     * Request html page containing the privacy policy
     * @return view
     */
    @GetMapping("/public/privacy-policy")
    public String privacyPolicy() {
        return "privacy-policy";
    }

    /**
     * Request html page containing the terms and conditions
     * @return view
     */
    @GetMapping("/public/agb")
    public String agb() {
        return "agb";
    }

    /**
     * Request html page 'website'
     * @return view
     */
    @GetMapping("/public/projects")
    public String website() {
        return "website";
    }

    /**
     * Request html page 'Kontakt'
     * @return view
     */
    @GetMapping("/public/projects/contact")
    public String contact() {
        return "Kontakt";
    }

    /**
     * Request html page 'About'
     * @return view
     */
    @GetMapping("/public/projects/about")
    public String about() {
        return "About";
    }

    /**
     * Request page for the web app version of the app
     * @return view
     */
    @GetMapping("/public/app")
    public String webApp() {
        return "index";
    }

    /**
     * Redirect to web app version
     * @param attributes not used
     * @return view
     */
    @GetMapping("/")
    public RedirectView redirectWithUsingRedirectView(
            RedirectAttributes attributes) {
        return new RedirectView("public/app");
    }

    /**
     * Request a user specific page to recover password.
     * @param url user specific url that is sent by the recovery mail
     * @param model thymeleaf specific attribute
     * @return view
     */
    @GetMapping("/public/recover/{url}")
    public String recoverPassword(@PathVariable("url") String url, Model model) {
        List<User> users = userRepo.getUsersWithUrl(url);
        if (users.size() == 1) {
            User user = users.get(0);
            String token = new JWTUtil().generateToken(user.getUsername(), user.getPassword());
            userRepo.updateUser(user.getUsername(), null, null, token);
            model.addAttribute("username", user.getUsername());
            model.addAttribute("token", token);
            return "recover";
        } else {
            throw new IllegalArgumentException("ERROR: This reset url does not exist");
        }
    }


}
