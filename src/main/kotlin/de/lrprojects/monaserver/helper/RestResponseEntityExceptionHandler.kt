package de.lrprojects.monaserver.helper

import com.google.firebase.messaging.FirebaseMessagingException
import de.lrprojects.monaserver.excepetion.*
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
    fun handleEntityNotFoundException(ex: EntityNotFoundException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.NOT_FOUND,
            request
        )
    }

    @ExceptionHandler(EmailNotConfirmedException::class)
    fun handleEmailNotConfirmedException(ex: EmailNotConfirmedException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.FORBIDDEN,
            request
        )
    }

    @ExceptionHandler(UserNotFoundException::class)
    fun handleUserNotFoundException(ex: UserNotFoundException, request: WebRequest): ResponseEntity<Any>? {
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
    fun handleUserExistsException(ex: UserExistsException, request: WebRequest): ResponseEntity<Any>? {
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
    fun handleAttributeDoesNotExist(ex: AttributeDoesNotExist, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(ImageProcessingException::class)
    fun handleImageProcessingException(ex: ImageProcessingException, request: WebRequest): ResponseEntity<Any>? {
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
    fun handleMailException(ex: MailException, request: WebRequest): ResponseEntity<Any>? {
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
    fun handleComparisonException(ex: ComparisonException, request: WebRequest): ResponseEntity<Any>? {
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
    fun handleAssertException(ex: AssertException, request: WebRequest): ResponseEntity<Any>? {
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
    fun handleDataIntegrityViolationException(ex: DataIntegrityViolationException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            "One or more fields are invalid",
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(NullPointerException::class)
    fun handleNullPointerException(ex: NullPointerException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.stackTraceToString())

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(TimeExpiredException::class)
    fun handleTimeExpiredException(ex: TimeExpiredException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.BAD_REQUEST,
            request
        )
    }

    @ExceptionHandler(AlreadyExistException::class)
    fun handleAlreadyExistsException(ex: AlreadyExistException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info(ex.message)

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.CONFLICT,
            request
        )
    }

    @ExceptionHandler(FirebaseMessagingException::class)
    fun handleFirebaseMessagingException(ex: FirebaseMessagingException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isWarnEnabled) log.warn("Error sending notification to topic: ${ex.message}")

        return handleExceptionInternal(
            ex,
            ex.message,
            HttpHeaders(),
            HttpStatus.SERVICE_UNAVAILABLE,
            request
        )
    }

    @ExceptionHandler(RuntimeException::class)
    fun handleRuntimeException(ex: RuntimeException, request: WebRequest): ResponseEntity<Any>? {
        if (log.isInfoEnabled) log.info("${ex.message} with cause: ${ex.cause?.message}")

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