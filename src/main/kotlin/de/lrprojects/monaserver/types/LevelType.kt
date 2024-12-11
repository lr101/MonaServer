package de.lrprojects.monaserver.types

enum class LevelType(val level: Int, val levelXp: Int) {
    NEWBIE(1, 0),
    BASIC(2, 25),
    NORMIE(3, 100),
    STICKER_LOVER(4, 1000),
    EXPERT(5, 5000),
    BUFF_LISA(6,10000);
    
    
    companion object {
        fun  getLevel(xp: Int): LevelType {
            return if (xp < NEWBIE.levelXp) {
                NEWBIE
            } else if (xp < BASIC.levelXp) {
                BASIC
            } else if (xp < NORMIE.levelXp) {
                NORMIE
            } else if (xp < STICKER_LOVER.levelXp) {
                STICKER_LOVER
            }else if (xp < EXPERT.levelXp) {
                EXPERT
            } else {
                BUFF_LISA
            }
        }
        
        fun getNextLevel(level: Int): LevelType {
            return when (level) {
                NEWBIE.level -> {
                    NEWBIE
                }
                BASIC.level -> {
                    BASIC
                }
                NORMIE.level -> {
                    NORMIE
                }
                STICKER_LOVER.level -> {
                    STICKER_LOVER
                }
                EXPERT.level -> {
                    EXPERT
                }
                else -> {
                    BUFF_LISA
                }
            }
        } 
    }
}