package de.lrprojects.monaserver.helper

import de.lrprojects.monaserver.excepetion.ImageProcessingException
import de.lrprojects.monaserver.types.ImageQualityType
import net.coobird.thumbnailator.Thumbnails
import org.springframework.core.io.ClassPathResource
import org.springframework.core.io.Resource
import org.springframework.stereotype.Component
import java.awt.Color
import java.awt.image.BufferedImage
import java.io.*
import javax.imageio.ImageIO
import kotlin.math.min


@Component
class ImageHelper {

    @Throws(ImageProcessingException::class)
    fun getProfileImage(image: ByteArray): ByteArray {
        return compressImage(image, SIZE_PROFILE, SIZE_PROFILE,true)
    }

    @Throws(ImageProcessingException::class)
    fun getProfileImageSmall(image: ByteArray): ByteArray {
        return compressImage(image, SIZE_PROFILE_SMALL, SIZE_PROFILE_SMALL, true)
    }

    @Throws(ImageProcessingException::class)
    fun getPinImage(image: ByteArray): ByteArray {
        return try {
            //scale to SIZE_PIN x SIZE_PIN
            val imageBuff = resizeImage(image, SIZE_GROUP_PIN_DIAMETER)
            //get Resources
            //create return image
            val returnImage = BufferedImage(SIZE_GROUP_PIN, SIZE_GROUP_PIN, BufferedImage.TYPE_INT_ARGB)
            val g = returnImage.createGraphics()
            for (x in 0 until SIZE_GROUP_PIN) {
                for (y in 0 until SIZE_GROUP_PIN) {
                    if (x >= SIZE_GROUP_PIN_X_OFFSET
                        && x <= SIZE_GROUP_PIN_X_OFFSET + SIZE_GROUP_PIN_DIAMETER
                        && y >= SIZE_GROUP_PIN_Y_OFFSET
                        && y <= SIZE_GROUP_PIN_Y_OFFSET + SIZE_GROUP_PIN_DIAMETER
                        && isNotTransparent(pinImage, x, y))
                    {
                        //draw image if pixel in pin_image.png is not transparent
                        g.color = Color(imageBuff.getRGB(x - SIZE_GROUP_PIN_X_OFFSET, y - SIZE_GROUP_PIN_Y_OFFSET))
                    } else if (isNotTransparent(pinBorder, x, y)) {
                        //draw image if pixel in pin_border.png is not transparent
                        g.color = Color(pinBorder.getRGB(x, y))
                    } else {
                        //default transparent
                        g.color = Color(0, 0, 0, 0)
                    }
                    g.drawLine(x, y, x, y)
                }
            }
            val buffer = ByteArrayOutputStream()
            ImageIO.write(returnImage, OUTPUT_FORMAT_PNG, buffer)
            g.dispose()
            imageBuff.flush()
            returnImage.flush()
            buffer.toByteArray()
        } catch (e: IllegalStateException) {
            throw ImageProcessingException("image does not have the right size constrains")
        } catch (e: FileNotFoundException) {
            throw ImageProcessingException("Static image template could not be accessed")
        } catch (e: NullPointerException) {
            throw ImageProcessingException("Image could not be processed, try a different format.")
        }
    }

    private fun isNotTransparent(image: BufferedImage, x: Int, y: Int): Boolean {
        val pixel = image.getRGB(x, y)
        return pixel shr 24 != 0x00
    }

    @Throws(ImageProcessingException::class)
    fun compressPinImage(image: ByteArray): ByteArray {
        return compressImage(image, WIDTH_PIN, HEIGHT_PIN)
    }

    @Throws(ImageProcessingException::class)
    private fun compressImage(image: ByteArray, width: Int, height: Int, forceSize: Boolean = false): ByteArray {
        try {
            val `in` = ByteArrayInputStream(image)
            val out = ByteArrayOutputStream()

            val originalSizeKB = image.size / 1024
            val dynamicQuality = calculateImageQuality(originalSizeKB)

            val builder = Thumbnails.of(`in`)
            if (forceSize) {
                builder.size(width, height)
            } else {
                builder.forceSize(width, height)
            }
            builder.outputQuality(dynamicQuality)
                .outputFormat(OUTPUT_FORMAT_JPG)
                .toOutputStream(out)

            `in`.close()
            val transformedImage = out.toByteArray()
            out.close()
            return transformedImage
        } catch (e: IOException) {
            throw ImageProcessingException("Image could not be compressed: ${e.message}")
        }
    }

    private fun calculateImageQuality(sizeKB: Int): Double {
        // Base the quality on size and resolution thresholds
        val sizeFactor = when {
            sizeKB > ImageQualityType.VERY_HIGH.kbSize -> ImageQualityType.VERY_HIGH.quality
            sizeKB > ImageQualityType.HIGH.kbSize -> ImageQualityType.HIGH.quality
            sizeKB > ImageQualityType.MEDIUM.kbSize -> ImageQualityType.MEDIUM.quality
            else ->  ImageQualityType.LOW.quality
        }

        // Ensure quality stays within bounds [0.1, 1.0]
        return min(sizeFactor, 1.0)
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
        private fun getImageFromResources(name: String): BufferedImage {
            val resource: Resource = ClassPathResource("pin/$name")
            val input = resource.inputStream
            val `in` = ByteArrayInputStream(input.readAllBytes())
            val img = ImageIO.read(`in`)
            input.close()
            `in`.close()
            return img
        }

        private val pinImage: BufferedImage = getImageFromResources("pin_image.png")
        private val pinBorder: BufferedImage = getImageFromResources("pin_border.png")
        private const val SIZE_PROFILE = 500
        private const val SIZE_GROUP_PIN = 100
        private const val SIZE_PROFILE_SMALL = 100
        private const val SIZE_GROUP_PIN_X_OFFSET = 11
        private const val SIZE_GROUP_PIN_Y_OFFSET = 4
        private const val SIZE_GROUP_PIN_DIAMETER = 79
        private const val WIDTH_PIN = 720
        private const val HEIGHT_PIN = 960
        private const val OUTPUT_FORMAT_JPG = "jpg"
        private const val OUTPUT_FORMAT_PNG = "png"
    }
}