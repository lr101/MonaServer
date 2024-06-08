package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.service.api.UserService
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable

@Controller
class ViewController (private val userService: UserService) {


    @GetMapping("/public/recover/{url}")
    fun recoverPassword(@PathVariable("url") url: String?, model: Model): String? {
        return try {
            val user = userService.getUserByRecoverUrl(url!!)
            model.addAttribute("username", user.username)
            model.addAttribute("token", user.token)
            "recover"
        } catch (e: Exception) {
            "404"
        }
    }

}
