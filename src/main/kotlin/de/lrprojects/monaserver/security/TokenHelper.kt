package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.properties.TokenProperties
import io.jsonwebtoken.Claims
import io.jsonwebtoken.Jwts
import org.springframework.stereotype.Component
import java.time.Instant
import java.util.*
import javax.crypto.SecretKey


@Component
class TokenHelper(
    private val tokenProperties: TokenProperties
) {
    fun extractUserId(token: String?): String {
        return extractClaim(token, Claims::getSubject)
    }

    fun extractExpiration(token: String?): Date {
        return extractClaim(token, Claims::getExpiration)
    }

    fun <T> extractClaim(token: String?, claimsResolver: (Claims) -> T): T {
        val claims: Claims = extractAllClaims(token)
        return claimsResolver(claims)
    }

    private fun extractAllClaims(token: String?): Claims {
        return Jwts
            .parser()
            .verifyWith(signKey)
            .build()
            .parseSignedClaims(token).payload
    }

    private fun isTokenExpired(token: String?): Boolean {
        return extractExpiration(token).before(Date())
    }

    fun validateToken(token: String?, userId: String): Boolean {
        val extractedUserId = extractUserId(token)
        return (extractedUserId == userId && !isTokenExpired(token))
    }


    fun generateToken(userId: UUID): String {
        val claims: Map<String, Any> = HashMap()
        return createToken(claims, userId)
    }


    private fun createToken(claims: Map<String, Any>, userId: UUID): String {
        return Jwts.builder()
            .claims(claims)
            .subject(userId.toString())
            .issuedAt(Date(System.currentTimeMillis()))
            .expiration(Date(Instant.now().plusSeconds(tokenProperties.accessTokenExploration).toEpochMilli()))
            .signWith(signKey).compact()
    }

    private val signKey: SecretKey = Jwts.SIG.HS256.key().build()

}