package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.config.TokenProperties
import io.jsonwebtoken.Claims
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.io.Decoders
import io.jsonwebtoken.security.Keys
import org.springframework.security.core.userdetails.UserDetails
import org.springframework.stereotype.Component
import java.time.Instant
import java.util.*
import javax.crypto.SecretKey


@Component
class TokenHelper(
    private val tokenProperties: TokenProperties
) {
    fun extractUsername(token: String?): String {
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

    fun validateToken(token: String?, userDetails: UserDetails): Boolean {
        val username = extractUsername(token)
        return (username == userDetails.username && !isTokenExpired(token))
    }


    fun generateToken(username: String): String {
        val claims: Map<String, Any> = HashMap()
        return createToken(claims, username)
    }


    private fun createToken(claims: Map<String, Any>, username: String): String {
        return Jwts.builder()
            .claims(claims)
            .subject(username)
            .issuedAt(Date(System.currentTimeMillis()))
            .expiration(Date(Instant.now().plusSeconds(tokenProperties.accessTokenExploration).toEpochMilli()))
            .signWith(signKey).compact()
    }

    private val signKey: SecretKey
        get() {
            val keyBytes: ByteArray = Decoders.BASE64.decode(tokenProperties.secret)
            return Keys.hmacShaKeyFor(keyBytes)
        }

}