package de.lrprojects.monaserver.helper

import de.lrprojects.monaserver.excepetion.ImageNotSquareException
import de.lrprojects.monaserver.excepetion.ProfileImageException
import org.springframework.core.io.ClassPathResource
import org.springframework.core.io.Resource
import org.springframework.stereotype.Component
import java.awt.Color
import java.awt.image.BufferedImage
import java.io.*
import javax.imageio.ImageIO


@Component
class ImageHelper {

    private val pinImage: BufferedImage = getImageFromResources("pin_image.png")
    private val pinBorder: BufferedImage = getImageFromResources("pin_border.png")
    private val size = 500
    private val sizePin = 100
    private val sizeSmall = 50
    private val xOffset = 11
    private val yOffset = 4
    private val diameter = 79


    fun getProfileImage(image: ByteArray): ByteArray {
        return getBytes(image, size)
    }

    fun getProfileImageSmall(image: ByteArray): ByteArray {
        return getBytes(image, sizeSmall)
    }

    private fun getBytes(image: ByteArray, sizeSmall: Int): ByteArray {
        return try {
            val imageBuff = resizeImage(image, sizeSmall)
            if (imageBuff.height != imageBuff.width) {
                throw ImageNotSquareException("the input image is not a square")
            }
            val buffer = ByteArrayOutputStream()
            ImageIO.write(imageBuff, "png", buffer)
            imageBuff.flush()
            buffer.toByteArray()
        } catch (e: IOException) {
            throw IllegalStateException("image does not have the right size constrains")
        } catch (e: IllegalStateException) {
            throw IllegalStateException("image does not have the right size constrains")
        }
    }

    fun getPinImage(image: ByteArray): ByteArray {
        return try {
            //scale to SIZE_PIN x SIZE_PIN
            val imageBuff = resizeImage(image, diameter)
            //get Resources
            //create return image
            val returnImage = BufferedImage(sizePin, sizePin, BufferedImage.TYPE_INT_ARGB)
            val g = returnImage.createGraphics()
            for (x in 0 until sizePin) {
                for (y in 0 until sizePin) {
                    if (x >= xOffset && x <= xOffset + diameter && y >= yOffset && y <= yOffset + diameter &&
                        isNotTransparent(pinImage, x, y)
                    ) {           //draw image if pixel in pin_image.png is not transparent
                        g.color = Color(imageBuff.getRGB(x - xOffset, y - yOffset))
                    } else if (isNotTransparent(
                            pinBorder,
                            x,
                            y
                        )
                    ) {   //draw image if pixel in pin_border.png is not transparent
                        g.color = Color(pinBorder.getRGB(x, y))
                    } else {                                        //default transparent
                        g.color = Color(0, 0, 0, 0)
                    }
                    g.drawLine(x, y, x, y)
                }
            }
            val buffer = ByteArrayOutputStream()
            ImageIO.write(returnImage, "png", buffer)
            g.dispose()
            imageBuff.flush()
            returnImage.flush()
            buffer.toByteArray()
        } catch (e: IllegalStateException) {
            throw ProfileImageException("image does not have the right size constrains")
        } catch (e: FileNotFoundException) {
            throw ProfileImageException("Static image template could not be accessed")
        } catch (e: NullPointerException) {
            throw ProfileImageException("Image could not be processed, try a different format.")
        }
    }

    private fun isNotTransparent(image: BufferedImage, x: Int, y: Int): Boolean {
        val pixel = image.getRGB(x, y)
        return pixel shr 24 != 0x00
    }


    @Throws(IOException::class)
    fun resizeImage(image: ByteArray, width: Int): BufferedImage {
        val `in` = ByteArrayInputStream(image)
        val originalImage = ImageIO.read(`in`)
        `in`.close()

        val originalWidth = originalImage.width
        val originalHeight = originalImage.height

        // Calculate the proportional height based on the provided width
        val height = (width.toDouble() / originalWidth.toDouble() * originalHeight.toDouble()).toInt()

        // Create a scaled instance of the original image
        val scaledImage = originalImage.getScaledInstance(width, height, BufferedImage.SCALE_SMOOTH)

        // Create a new BufferedImage with the scaled dimensions
        val resizedImage = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)

        // Draw the scaled image onto the new BufferedImage
        val graphics2D = resizedImage.createGraphics()
        graphics2D.drawImage(scaledImage, 0, 0, Color(0, 0, 0), null)
        graphics2D.dispose()

        return resizedImage
    }

    companion object {
        fun getImageFromResources(name: String): BufferedImage {
            val resource: Resource = ClassPathResource("pin/$name")
            val input = resource.inputStream
            val `in` = ByteArrayInputStream(input.readAllBytes())
            val img = ImageIO.read(`in`)
            input.close()
            `in`.close()
            return img
        }
    }
}