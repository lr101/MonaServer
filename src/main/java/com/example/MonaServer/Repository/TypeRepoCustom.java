package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.StickerType;

public interface TypeRepoCustom {

    public StickerType getStickerTypeById(Long id);
    public void deleteType(StickerType stickerType);
    public StickerType updateType(StickerType stickerType);
}
