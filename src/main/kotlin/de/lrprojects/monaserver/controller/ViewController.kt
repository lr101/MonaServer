package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.excepetion.TimeExpiredException
import de.lrprojects.monaserver.security.TokenHelper
import de.lrprojects.monaserver.service.api.UserService
import org.slf4j.LoggerFactory
import org.springframework.core.io.ClassPathResource
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable

@Controller
class ViewController (
    private val userService: UserService,
    private val tokenHelper: TokenHelper,
) {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }


    @GetMapping("/public/recover/{url}")
    fun recoverPassword(@PathVariable("url") url: String?, model: Model): String? {
        log.info("Trying password recovery view'")
        return try {
            val user = userService.getUserByRecoverUrl(url!!)
            log.info("Displaying password recovery view for user ${user.username}'")
            model.addAttribute("userId", user.id)
            model.addAttribute("token", tokenHelper.generateToken(user.id!!))
            "recover-view"
        } catch (e: TimeExpiredException) {
            return "time-expired"
        } catch (e: Exception) {
            "404"
        }
    }

    @GetMapping("/public/delete-account/code")
    fun requestDeleteCodeView(): String {
        log.info("Displaying request delete code view")
        return "request-delete-view"
    }

    @GetMapping("/public/agb")
    fun requestAgb(): String {
        log.info("Displaying agb")
        return "agb"
    }

    @GetMapping("/public/privacy-policy")
    fun requestPrivacyPolicy(): String {
        log.info("Displaying privacy policy")
        return "privacy-policy"
    }

    @GetMapping("/public/email-confirmation/{url}")
    fun emailConfirmationView(@PathVariable("url") url: String, model: Model): String {
        log.info("Displaying email confirmation view")
        return try {
            val user = userService.getUserByEmailConfirmationUrl(url)
            model.addAttribute("username", user.username)
            "email-confirmation-view"
        } catch (e: Exception) {
            "404"
        }
    }

    @GetMapping("/public/delete-account/{url}")
    fun deleteAccountView(@PathVariable("url") url: String, model: Model): String {
        log.info("Displaying delete account view")
        return try {
            val user = userService.getUserByDeletionUrl(url)
            model.addAttribute("userId", user.id)
            model.addAttribute("username", user.username)
            model.addAttribute("token", tokenHelper.generateToken(user.id!!))
            "delete-view"
        } catch (e: TimeExpiredException) {
            "time-expired"
        } catch (e: Exception) {
                "404"
        }
    }

    @GetMapping("/favicon.ico")
    fun getFavicon(): ResponseEntity<*> {
        val favicon = ClassPathResource("static/favicon.ico")
        return ResponseEntity.ok()
            .header("Content-Type", "image/x-icon")
            .body(favicon)
    }

}
