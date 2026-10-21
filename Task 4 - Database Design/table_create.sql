CREATE TABLE users (
    user_id        INT GENERATED ALWAYS AS IDENTITY,
    username       VARCHAR(50)  NOT NULL,
    email          VARCHAR(255) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    phone_number   VARCHAR(20),                     -- optional
    tier           VARCHAR(10)  NOT NULL DEFAULT 'free',

    CONSTRAINT pk_users          PRIMARY KEY (user_id),
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_email    UNIQUE (email),
    CONSTRAINT uq_users_phone    UNIQUE (phone_number),
    CONSTRAINT ck_users_tier     CHECK (tier IN ('free', 'premium', 'business'))
);

CREATE TABLE user_preferences (
    user_id            INT          NOT NULL,
    bio                VARCHAR(500),
    theme              VARCHAR(10)  NOT NULL DEFAULT 'light',
    profile_image_url  VARCHAR(500),
    avatar_frame       VARCHAR(50),
    kids_mode          BOOLEAN      NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_user_preferences PRIMARY KEY (user_id),
    CONSTRAINT fk_user_preferences_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_user_preferences_theme CHECK (theme IN ('light', 'dark', 'custom'))
);

CREATE TABLE friends (
    user_id     INT       NOT NULL,
    friend_id   INT       NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_friendship PRIMARY KEY (user_id, friend_id),
    CONSTRAINT fk_friendship_user
        FOREIGN KEY (user_id)   REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT fk_friendship_friend
        FOREIGN KEY (friend_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_friendship_order CHECK (user_id < friend_id)   -- no self-friending, no (A,B)+(B,A)
);

-- user interest stuff -------------------------------------

CREATE TABLE category (
    category_id  INT GENERATED ALWAYS AS IDENTITY,
    name         VARCHAR(50) NOT NULL,

    CONSTRAINT pk_category      PRIMARY KEY (category_id),
    CONSTRAINT uq_category_name UNIQUE (name)
);

CREATE TABLE user_interest (
    user_id      INT NOT NULL,
    category_id  INT NOT NULL,

    CONSTRAINT pk_user_interest PRIMARY KEY (user_id, category_id),
    CONSTRAINT fk_user_interest_user
        FOREIGN KEY (user_id)     REFERENCES users (user_id)       ON DELETE CASCADE,
    CONSTRAINT fk_user_interest_category
        FOREIGN KEY (category_id) REFERENCES category (category_id) ON DELETE CASCADE
);

CREATE TABLE user_category_activity (
    user_id           INT       NOT NULL,
    category_id       INT       NOT NULL,
    last_activity_at  TIMESTAMP NOT NULL,
    activity_count    INT       NOT NULL DEFAULT 0,

    CONSTRAINT pk_user_category_activity PRIMARY KEY (user_id, category_id),
    CONSTRAINT fk_uca_user
        FOREIGN KEY (user_id)     REFERENCES users (user_id)        ON DELETE CASCADE,
    CONSTRAINT fk_uca_category
        FOREIGN KEY (category_id) REFERENCES category (category_id) ON DELETE CASCADE,
    CONSTRAINT ck_uca_count CHECK (activity_count >= 0)
);

-- Posts Stuff ----------------------------------------------
CREATE TABLE posts (
    post_id         INT GENERATED ALWAYS AS IDENTITY,
    user_id         INT          NOT NULL,          -- author
    privacy         VARCHAR(12)  NOT NULL DEFAULT 'public',
    text_content    TEXT,
    image_url       VARCHAR(500),
    forum_progress  SMALLINT     NOT NULL DEFAULT 0,
    is_boosted      BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_posts PRIMARY KEY (post_id),
    CONSTRAINT fk_posts_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT ck_posts_privacy  CHECK (privacy IN ('public', 'friends_only')),
    CONSTRAINT ck_posts_content  CHECK (text_content IS NOT NULL OR image_url IS NOT NULL),
    CONSTRAINT ck_posts_progress CHECK (forum_progress BETWEEN 0 AND 100)
);

CREATE TABLE favorite (
    user_id  INT NOT NULL,
    post_id  INT NOT NULL,

    CONSTRAINT pk_favorite PRIMARY KEY (user_id, post_id),
    CONSTRAINT fk_favorite_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT fk_favorite_post
        FOREIGN KEY (post_id) REFERENCES posts (post_id) ON DELETE CASCADE
);

CREATE TABLE comments (
    comment_id  INT GENERATED ALWAYS AS IDENTITY,
    post_id     INT       NOT NULL,
    user_id     INT       NOT NULL,
    body        TEXT      NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_comment PRIMARY KEY (comment_id),
    CONSTRAINT fk_comment_post
        FOREIGN KEY (post_id) REFERENCES posts (post_id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);

CREATE TABLE post_like (
    post_id  INT NOT NULL,
    user_id  INT NOT NULL,

    CONSTRAINT pk_post_like PRIMARY KEY (post_id, user_id),
    CONSTRAINT fk_post_like_post
        FOREIGN KEY (post_id) REFERENCES posts (post_id) ON DELETE CASCADE,
    CONSTRAINT fk_post_like_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);

CREATE TABLE post_reaction (                        -- one reaction per user per post
    post_id        INT         NOT NULL,
    user_id        INT         NOT NULL,
    reaction_type  VARCHAR(20) NOT NULL,

    CONSTRAINT pk_post_reaction PRIMARY KEY (post_id, user_id),
    CONSTRAINT fk_post_reaction_post
        FOREIGN KEY (post_id) REFERENCES posts (post_id) ON DELETE CASCADE,
    CONSTRAINT fk_post_reaction_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- Messaging
-- ---------------------------------------------------------------------
CREATE TABLE chat (
    chat_id  INT GENERATED ALWAYS AS IDENTITY,
    user1_id         INT          NOT NULL,
    user2_id         INT          NOT NULL,
    background       VARCHAR(100) NOT NULL DEFAULT 'default',
    accent_color     CHAR(7)      NOT NULL DEFAULT '#000000',

    CONSTRAINT pk_chat PRIMARY KEY (chat_id),
    CONSTRAINT fk_chat_user1
        FOREIGN KEY (user1_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT fk_chat_user2
        FOREIGN KEY (user2_id) REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT uq_chat_pair  UNIQUE (user1_id, user2_id),
    CONSTRAINT ck_chat_order CHECK (user1_id < user2_id)  -- one chat per pair
);

CREATE TABLE chat_buffer (                  -- per-user draft/buffer for a conversation
    chat_id  INT  NOT NULL,
    user_id          INT  NOT NULL,
    buffer_text      TEXT NOT NULL DEFAULT '',

    CONSTRAINT pk_chat_buffer PRIMARY KEY (chat_id, user_id),
    CONSTRAINT fk_chat_buffer_chat
        FOREIGN KEY (chat_id) REFERENCES chat (chat_id) ON DELETE CASCADE,
    CONSTRAINT fk_chat_buffer_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);

CREATE TABLE message (
    message_id       INT GENERATED ALWAYS AS IDENTITY,
    chat_id  INT       NOT NULL,
    sender_id        INT       NOT NULL,
    body             TEXT      NOT NULL,
    sent_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_message PRIMARY KEY (message_id),
    CONSTRAINT fk_message_chat
        FOREIGN KEY (chat_id) REFERENCES chat (chat_id) ON DELETE CASCADE,
    CONSTRAINT fk_message_sender
        FOREIGN KEY (sender_id) REFERENCES users (user_id) ON DELETE CASCADE
);

CREATE TABLE message_reaction (
    message_id     INT         NOT NULL,
    user_id        INT         NOT NULL,
    reaction_type  VARCHAR(20) NOT NULL,

    CONSTRAINT pk_message_reaction PRIMARY KEY (message_id, user_id),
    CONSTRAINT fk_message_reaction_message
        FOREIGN KEY (message_id) REFERENCES message (message_id) ON DELETE CASCADE,
    CONSTRAINT fk_message_reaction_user
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
);
