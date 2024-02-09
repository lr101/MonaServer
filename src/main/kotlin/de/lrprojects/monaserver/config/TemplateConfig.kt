package de.lrprojects.monaserver.config

import org.springframework.context.ApplicationContext
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.stereotype.Component
import org.thymeleaf.spring5.SpringTemplateEngine
import org.thymeleaf.spring5.templateresolver.SpringResourceTemplateResolver
import org.thymeleaf.templatemode.TemplateMode


@Configuration
class TemplateConfig (@Autowired val applicationContext: ApplicationContext) {

    @Bean
    fun templateResolver(): SpringResourceTemplateResolver? {
        val templateResolver = SpringResourceTemplateResolver()
        templateResolver.setApplicationContext(this.applicationContext)
        templateResolver.prefix = "classpath:/templates/";
        templateResolver.suffix = ".html";
        templateResolver.templateMode = TemplateMode.HTML
        templateResolver.isCacheable = true
        return templateResolver
    }

    @Bean
    fun templateEngine(): SpringTemplateEngine? {
        val templateEngine = SpringTemplateEngine()
        templateEngine.setTemplateResolver(templateResolver())
        templateEngine.enableSpringELCompiler = true
        return templateEngine
    }

}