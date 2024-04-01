package de.lrprojects.monaserver.config

import io.swagger.v3.oas.annotations.OpenAPIDefinition
import io.swagger.v3.oas.annotations.security.SecurityRequirement
import io.swagger.v3.oas.models.Components
import io.swagger.v3.oas.models.OpenAPI
import io.swagger.v3.oas.models.security.SecurityScheme
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration


@Configuration
@OpenAPIDefinition(security = [SecurityRequirement(name = "token")])
class SwaggerConfig {
    @Bean
    fun swaggerApiConfig(): OpenAPI {
        val components = Components()
            .addSecuritySchemes(
                "token", SecurityScheme()
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")
            )
        return OpenAPI().components(components)
    }
}