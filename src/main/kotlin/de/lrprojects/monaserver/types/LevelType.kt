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
            return  if (xp < BASIC.levelXp) {
                NEWBIE
            } else if (xp < NORMIE.levelXp) {
                BASIC
            } else if (xp < STICKER_LOVER.levelXp) {
                NORMIE
            }else if (xp < EXPERT.levelXp) {
                STICKER_LOVER
            } else if (xp < BUFF_LISA.levelXp){
                EXPERT
            } else {
                BUFF_LISA
            }
        }
        
        fun getNextLevel(level: Int): LevelType {
            return when (level) {
                NEWBIE.level -> {
                    BASIC
                }
                BASIC.level -> {
                    NORMIE
                }
                NORMIE.level -> {
                    STICKER_LOVER
                }
                STICKER_LOVER.level -> {
                    EXPERT
                }
                EXPERT.level -> {
                    BUFF_LISA
                }
                else -> {
                    BUFF_LISA
                }
            }
        } 
    }
}