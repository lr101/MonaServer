package de.lrprojects.monaserver.security

import org.springframework.security.crypto.password.PasswordEncoder
import java.security.MessageDigest

class NoSaltPasswordEncoder : PasswordEncoder {

    private val digest = MessageDigest.getInstance("SHA-256");

    override fun encode(rawPassword: CharSequence): String {
        val hash = digest.digest(rawPassword.toString().toByteArray())
        return hash.joinToString("") { "%02x".format(it) }
    }

    override fun matches(rawPassword: CharSequence, encodedPassword: String): Boolean {
        return encode(rawPassword) == encodedPassword
    }

    override fun upgradeEncoding(encodedPassword: String?): Boolean {
        return true
    }

}