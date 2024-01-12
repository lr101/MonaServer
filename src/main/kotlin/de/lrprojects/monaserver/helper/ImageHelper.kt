package de.lrprojects.monaserver.helper

import org.springframework.core.io.ClassPathResource
import org.springframework.core.io.Resource
import java.awt.Color
import java.awt.Image
import java.awt.image.BufferedImage
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import javax.imageio.ImageIO

object ImageHelper {
    private const val SIZE = 500
    private const val SIZE_PIN = 100
    private const val SIZE_SMALL = 50
    private const val X_OFFSET = 11
    private const val Y_OFFSET = 4
    private const val DIAMETER = 79
    const val HEX_COLOR_TRANSPARENT = 0xFFFFFF
    fun getProfileImage(image: ByteArray): ByteArray {
        return getBytes(image, SIZE)
    }

    fun getProfileImageSmall(image: ByteArray): ByteArray {
        return getBytes(image, SIZE_SMALL)
    }

    private fun getBytes(image: ByteArray, sizeSmall: Int): ByteArray {
        return try {
            val imageBuff = resizeImage(image, sizeSmall)
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
            val imageBuff = resizeImage(image, DIAMETER)
            //get Resources
            val pinImage = getImageFromResources("pin_image.png")
            val pinBorder = getImageFromResources("pin_border.png")
            //create return image
            val returnImage = BufferedImage(SIZE_PIN, SIZE_PIN, BufferedImage.TYPE_INT_ARGB)
            val g = returnImage.createGraphics()
            for (x in 0 until SIZE_PIN) {
                for (y in 0 until SIZE_PIN) {
                    if (x >= X_OFFSET && x <= X_OFFSET + DIAMETER && y >= Y_OFFSET && y <= Y_OFFSET + DIAMETER &&
                        isNotTransparent(pinImage, x, y)
                    ) {           //draw image if pixel in pin_image.png is not transparent
                        g.color = Color(imageBuff.getRGB(x - X_OFFSET, y - Y_OFFSET))
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
            pinImage.flush()
            pinBorder.flush()
            returnImage.flush()
            buffer.toByteArray()
        } catch (e: Exception) {
            println(e)
            throw IllegalStateException("image does not have the right size constrains")
        }
    }

    private fun isNotTransparent(image: BufferedImage, x: Int, y: Int): Boolean {
        val pixel = image.getRGB(x, y)
        return pixel shr 24 != 0x00
    }

    @Throws(IOException::class)
    private fun resizeImage(image: ByteArray, size: Int): BufferedImage {
        val `in` = ByteArrayInputStream(image)
        val img = ImageIO.read(`in`)
        `in`.close()
        val scaledImage = img.getScaledInstance(size, size, Image.SCALE_SMOOTH)
        val imageBuff = BufferedImage(size, size, BufferedImage.TYPE_INT_RGB)
        imageBuff.graphics.drawImage(scaledImage, 0, 0, Color(0, 0, 0), null)
        scaledImage.flush()
        return imageBuff
    }

    @Throws(IOException::class)
    private fun getImageFromResources(name: String): BufferedImage {
        val resource: Resource = ClassPathResource("pin/$name")
        val input = resource.inputStream
        val `in` = ByteArrayInputStream(input.readAllBytes())
        val img = ImageIO.read(`in`)
        input.close()
        `in`.close()
        return img
    }
}