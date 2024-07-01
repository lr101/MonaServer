package de.lrprojects.monaserver.security

import jakarta.servlet.FilterChain
import jakarta.servlet.ServletException
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.hibernate.query.sqm.tree.SqmNode.log
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource
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
        val authHeader: String? = request.getHeader("Authorization")
        val jwt: String
        try {
            if (!authHeader.isNullOrEmpty() && authHeader.startsWith("Bearer ")) {
                jwt = authHeader.substring(7)
                log.info(request.requestURI)
                val username = tokenHelper.extractUsername(jwt)
                val userDetails = userDetailsService.loadUserByUsername(username)
                if(tokenHelper.validateToken(jwt, userDetails)) {
                    val authToken = UsernamePasswordAuthenticationToken(username, null, userDetails.authorities)
                    authToken.details = WebAuthenticationDetailsSource().buildDetails(request)
                    SecurityContextHolder.getContext().authentication = authToken
                }
            }
        } catch (e: Exception) {
            log.warn("Unauthorized user token")
        }
        filterChain.doFilter(request, response)
    }
}