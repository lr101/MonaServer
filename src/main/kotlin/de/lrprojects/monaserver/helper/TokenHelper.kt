package de.lrprojects.monaserver.helper

import com.auth0.jwt.JWT
import com.auth0.jwt.JWTVerifier
import com.auth0.jwt.algorithms.Algorithm
import com.auth0.jwt.exceptions.JWTCreationException
import com.auth0.jwt.exceptions.JWTVerificationException
import com.auth0.jwt.interfaces.DecodedJWT
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import java.util.*

@Component
class TokenHelper (@Value("secrets.token.value") val secret: String) {


    @Throws(IllegalArgumentException::class, JWTCreationException::class)
    fun generateToken(username: String?, password: String?, userId: UUID?): String? {
        return JWT.create()
            .withSubject("User Details")
            .withClaim("username", username)
            .withClaim("id", userId.toString())
            .withClaim("password", password)
            .withIssuedAt(Date())
            .withIssuer("MONA_SERVER/LUKAS_REIM")
            .sign(Algorithm.HMAC256(secret))
    }

    @Throws(JWTVerificationException::class)
    fun validateTokenAndRetrieveSubject(token: String?): Triple<String, String?, UUID?> {
        val verifier: JWTVerifier = JWT.require(Algorithm.HMAC256(secret))
            .withSubject("User Details")
            .withIssuer("MONA_SERVER/LUKAS_REIM")
            .build()
        val jwt: DecodedJWT = verifier.verify(token)
        val uuid = jwt.getClaim("id")?.asString()
        return Triple(jwt.getClaim("username").asString(),jwt.getClaim("password")?.asString(), if (uuid != null) UUID.fromString(uuid) else null )
    }
}