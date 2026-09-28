ALTER TABLE users DROP CONSTRAINT users_selected_batch_color_check;
ALTER TABLE users
    ADD CONSTRAINT users_selected_batch_color_check
    CHECK (selected_batch_color IN (
        'default',
        '#FF8BC34A',
        '#FFFF5252',
        '#FF64FFDA',
        '#FFE91E63',
        '#FFFF9800',
        '#FF2196F3',
        '#FFFF7043',
        '#FF673AB7',
        '#FF00ACC1',
        '#FF9C27B0',
        '#FFFFC107',
        '#FF3F51B5',
        '#FF7CB342',
        '#FFE53935',
        '#FFC62828',
        '#FF26A69A',
        '#FFD81B60',
        '#FFC2185B',
        '#FFEF6C00',
        '#FFFF5722',
        '#FFD4E157',
        '#FF7B1FA2',
        '#FF795548'
    ));
