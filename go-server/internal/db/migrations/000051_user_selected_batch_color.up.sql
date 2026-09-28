ALTER TABLE users
    ADD COLUMN selected_batch_color varchar(9) NOT NULL DEFAULT 'default'
    CHECK (selected_batch_color IN (
        'default',
        '#FF8BC34A',
        '#FFFF5252',
        '#FF64FFDA',
        '#FFE91E63',
        '#FFFF9800'
    ));
