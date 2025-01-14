package de.lrprojects.monaserver.types

enum class ImageQualityType(val quality: Double, val kbSize: Int) {
    LOW(0.9, 250),
    MEDIUM(0.8, 750),
    HIGH(0.5, 1500),
    VERY_HIGH(0.3, 2500);

}