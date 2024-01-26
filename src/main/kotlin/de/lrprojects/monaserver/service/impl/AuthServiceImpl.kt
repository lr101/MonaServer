package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.excepetion.*
import de.lrprojects.monaserver.helper.SecurityHelper
import de.lrprojects.monaserver.helper.TokenHelper
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.AuthService
import de.lrprojects.monaserver.service.api.EmailService
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import kotlin.jvm.optionals.getOrElse

@Service

class AuthServiceImpl constructor(
    @Autowired val userRepository: UserRepository,
    @Autowired val tokenHelper: TokenHelper,
    @Autowired val emailService: EmailService
) : AuthService{

    @Throws(UserExistsException::class)
    override fun signup(username: String, password: String, email: String): String {
        val user = User()
        user.email = email
        user.username = username
        user.password = password
        try {
            user.token = tokenHelper.generateToken(username, password)
            userRepository.save(user)
        } catch (_: Error) {
            throw UserExistsException("user with username " + username + "already exists")
        }

        return username
    }

    @Throws(WrongPasswordException::class, UserNotFoundException::class)
    override fun login(username: String, password: String): String {
        val user = userRepository.findById(username).getOrElse { throw UserNotFoundException("user does not exist") }
        if (user.password.equals(password)) {
            if (user.token.isNullOrEmpty()) {
                user.token = tokenHelper.generateToken(user.username, user.password)
            }
            return user.token!!
        } else {
            throw WrongPasswordException("password don not match")
        }

    }

    @Throws(AttributeDoesNotExist::class, MailException::class, UniqueResetUrlNotFoundException::class)
    override fun recoverPassword(username: String) {
        val user = userRepository.findById(username).getOrElse { throw UserNotFoundException("user does not exist") }
        var resetUrl: String
        var attempts = 0

        if (user.email.isNullOrEmpty()) {
            throw AttributeDoesNotExist("No email address exists")
        }

        do {
            resetUrl = SecurityHelper.generateAlphabeticRandomString(25)
            attempts++
        } while (userRepository.findByResetPasswordUrl(resetUrl).isEmpty && attempts < 10)

        if (attempts >= 10) {
            throw UniqueResetUrlNotFoundException("Failed to generate a unique reset URL after 10 attempts.")
        } else {
            user.resetPasswordUrl = resetUrl
            userRepository.save(user)
            emailService.sendMail("Reset url at " + user.resetPasswordUrl, user.email!!, "Reset Password")
        }
    }

    @Throws(AttributeDoesNotExist::class, MailException::class)
    override fun requestDeleteCode(username: String) {
        val user = userRepository.findById(username).getOrElse { throw UserNotFoundException("user does not exist") }

        if (user.email.isNullOrEmpty()) {
            throw AttributeDoesNotExist("No email address exists")
        }
        user.code = SecurityHelper.generateSixDigitNumber()
        userRepository.save(user)
        emailService.sendMail("Reset url at " + user.code, user.email!!, "Delete Code")
    }
}