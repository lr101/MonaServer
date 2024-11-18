package de.lrprojects.monaserver.security

import jakarta.servlet.FilterChain
import jakarta.servlet.ServletException
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.hibernate.query.sqm.tree.SqmNode.log
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.io.IOException


@Component
class JWTFilter (
    private val userDetailsService: UserDetailsService,
    private val tokenHelper: TokenHelper
) : OncePerRequestFilter() {

    @Throws(ServletException::class, IOException::class)
    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        log.info("Checking authentication for " + request.requestURI)
        val authHeader: String? = request.getHeader("Authorization")
        val jwt: String
        try {
            if (!authHeader.isNullOrEmpty() && authHeader.startsWith("Bearer ")) {
                jwt = authHeader.substring(7)
                val username = tokenHelper.extractUsername(jwt)
                val userDetails = userDetailsService.loadUserByUsername(username)
                if(tokenHelper.validateToken(jwt, userDetails)) {
                    val authToken = UsernamePasswordAuthenticationToken(userDetails.username, username, userDetails.authorities)
                    authToken.details = WebAuthenticationDetailsSource().buildDetails(request)
                    SecurityContextHolder.getContext().authentication = authToken
                } else {
                    log.warn("Unauthorized user token")
                }
            }
        } catch (e: Exception) {
            log.warn("Unauthorized user token ${e.message}")
            //response.sendError(HttpServletResponse.SC_UNAUTHORIZED)
            //return
        }
        filterChain.doFilter(request, response)
    }
}