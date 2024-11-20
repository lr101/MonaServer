package de.lrprojects.monaserver.helper

import de.lrprojects.monaserver.excepetion.AssertException
import de.lrprojects.monaserver.excepetion.AttributeDoesNotExist
import de.lrprojects.monaserver.excepetion.ComparisonException
import de.lrprojects.monaserver.excepetion.ImageNotSquareException
import de.lrprojects.monaserver.excepetion.MailException
import de.lrprojects.monaserver.excepetion.ProfileImageException
import de.lrprojects.monaserver.excepetion.TimeExpiredException
import de.lrprojects.monaserver.excepetion.UserExistsException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import jakarta.persistence.EntityNotFoundException
import org.slf4j.LoggerFactory
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.context.request.WebRequest
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler

@ControllerAdvice
class RestResponseEntityExceptionHandler : ResponseEntityExceptionHandler() {


    @ExceptionHandler(EntityNotFoundException::class)
    protected fun handleEntityNotFoundException(ex: EntityNotFoundException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.NOT_FOUND,
            request
        )
    }

    @ExceptionHandler(UserNotFoundException::class)
    protected fun handleUserNotFoundException(ex: UserNotFoundException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.NOT_FOUND,
            request
        )
    }

    @ExceptionHandler(UserExistsException::class)
    protected fun handleUserExistsException(ex: UserExistsException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.CONFLICT,
            request
        )
    }

    @ExceptionHandler(AttributeDoesNotExist::class)
    protected fun handleAttributeDoesNotExist(ex: AttributeDoesNotExist, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(ProfileImageException::class)
    protected fun handleProfileImageException(ex: ProfileImageException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(MailException::class)
    protected fun handleMailException(ex: MailException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(ComparisonException::class)
    protected fun handleComparisonException(ex: ComparisonException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(ImageNotSquareException::class)
    protected fun handleImageNotSquareException(ex: ImageNotSquareException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(AssertException::class)
    protected fun handleAssertException(ex: AssertException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(DataIntegrityViolationException::class)
    protected fun handleDataIntegrityViolationException(ex: DataIntegrityViolationException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            "This name does already exist",
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(NullPointerException::class)
    protected fun handleNullPointerException(ex: NullPointerException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(TimeExpiredException::class)
    protected fun handleTimeExpiredException(ex: TimeExpiredException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(RuntimeException::class)
    protected fun handleNRuntimeException(ex: RuntimeException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    companion object {
        private val log by lazy { LoggerFactory.getLogger(this::class.java.declaringClass) }
    }

}