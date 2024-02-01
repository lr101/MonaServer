package de.lrprojects.monaserver.security

import com.auth0.jwt.exceptions.JWTVerificationException
import de.lrprojects.monaserver.helper.TokenHelper
import jakarta.servlet.FilterChain
import jakarta.servlet.ServletException
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.hibernate.query.sqm.tree.SqmNode.log
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.io.IOException


@Component
class JWTFilter (
    @Autowired val userDetailsService: MyUserDetailsService,
    @Autowired val tokenHelper: TokenHelper
) : OncePerRequestFilter() {

    @Throws(ServletException::class, IOException::class)
    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val authHeader: String = request.getHeader("Authorization")
        if (authHeader.isNotBlank() && authHeader.startsWith("Bearer ")) {
            val jwt = authHeader.substring(7)
            if (jwt.isBlank()) {
                response.sendError(HttpServletResponse.SC_BAD_REQUEST, "No Token provided")
            } else {
                try {
                    log.info(request.requestURI)
                    val m: Pair<String, String?> = tokenHelper.validateTokenAndRetrieveSubject(jwt)
                    val userDetails = userDetailsService.loadUserByUsername(m.first)
                    val authToken = UsernamePasswordAuthenticationToken(
                        m.first,
                        if (m.second != null || m.first == "lr") m.second else userDetails.password,
                        userDetails.authorities
                    )
                    if (SecurityContextHolder.getContext().authentication == null) {
                        SecurityContextHolder.getContext().authentication = authToken
                    }
                    if (authToken.credentials == null || authToken.credentials != userDetails.password) throw JWTVerificationException("Token invalid")
                } catch (exc: JWTVerificationException) {
                    response.sendError(HttpServletResponse.SC_BAD_REQUEST, "Invalid JWT Token")
                }
            }
        }
        filterChain.doFilter(request, response)
    }
}