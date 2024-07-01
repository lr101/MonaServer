package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.security.TokenHelper
import de.lrprojects.monaserver.service.api.UserService
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable

@Controller
class ViewController (
    private val userService: UserService,
    private val tokenHelper: TokenHelper,
) {


    @GetMapping("/public/recover/{url}")
    fun recoverPassword(@PathVariable("url") url: String?, model: Model): String? {
        return try {
            val user = userService.getUserByRecoverUrl(url!!)
            model.addAttribute("userId", user.id)
            model.addAttribute("token", tokenHelper.generateToken(user.username))
            "recover-view"
        } catch (e: Exception) {
            "404"
        }
    }

    @GetMapping("/public/delete-account/code")
    fun requestDeleteCodeView(): String {
        return "request-delete-view"
    }

    @GetMapping("/public/delete-account/{url}")
    fun deleteAccountView(@PathVariable("url") url: String, model: Model): String {
        return try {
            val user = userService.getUserByRecoverUrl(url)
            model.addAttribute("userId", user.id)
            model.addAttribute("username", user.username)
            model.addAttribute("token", tokenHelper.generateToken(user.username))
            "delete-view"
        } catch (e: Exception) {
            "404"
        }
    }

}
