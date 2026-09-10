-- ============================================
-- Инициализация БД фитнес-клуба «Сила»
-- Версия: 1.0 (доработка системы)
-- ============================================

-- Существующие таблицы (из Задания 6)
CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    push_token VARCHAR(512),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'month', 'quarter', 'year'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'expired', 'frozen'
    freeze_status VARCHAR(20) DEFAULT 'active', -- 'active', 'frozen'
    frozen_until DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    class_type VARCHAR(30) NOT NULL, -- 'group', 'martial_arts', 'personal'
    description TEXT,
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_minutes INTEGER NOT NULL DEFAULT 60,
    max_capacity INTEGER NOT NULL DEFAULT 20,
    includes_equipment BOOLEAN DEFAULT FALSE,
    trainer_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'cancelled', 'completed'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    cancelled_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    method VARCHAR(30) NOT NULL, -- 'card', 'cash'
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'success', 'failed', 'refunded'
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================
-- НОВЫЕ ТАБЛИЦЫ (доработка системы)
-- ============================================

-- Электронные карты доступа
CREATE TABLE access_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_number VARCHAR(50) UNIQUE NOT NULL,
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'blocked', 'lost'
    issued_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    blocked_at TIMESTAMP WITH TIME ZONE,
    reissue_count INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_access_cards_client ON access_cards(client_id);
CREATE INDEX idx_access_cards_status ON access_cards(status);

-- Журнал посещений (вход/выход)
CREATE TABLE visit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL REFERENCES access_cards(id),
    client_id UUID NOT NULL REFERENCES clients(id),
    entry_time TIMESTAMP WITH TIME ZONE NOT NULL,
    exit_time TIMESTAMP WITH TIME ZONE,
    turnstile_id VARCHAR(50) NOT NULL,
    event_type VARCHAR(10) NOT NULL, -- 'entry', 'exit'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_visit_logs_client ON visit_logs(client_id);
CREATE INDEX idx_visit_logs_entry ON visit_logs(entry_time);
CREATE INDEX idx_visit_logs_open ON visit_logs(client_id) WHERE exit_time IS NULL;

-- Лист ожидания
CREATE TABLE waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'waiting', -- 'waiting', 'booked', 'cancelled', 'expired'
    added_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    notified_at TIMESTAMP WITH TIME ZONE,
    UNIQUE (class_id, client_id, status)
);

CREATE INDEX idx_waitlist_class ON waitlist(class_id, status);
CREATE INDEX idx_waitlist_position ON waitlist(class_id, position);

-- Тренеры
CREATE TABLE trainers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(255) NOT NULL,
    specialization VARCHAR(50) NOT NULL, -- 'boxing', 'judo', 'yoga', 'pilates', 'cycle', 'personal'
    rating DECIMAL(3, 2) CHECK (rating >= 0 AND rating <= 5),
    hourly_rate DECIMAL(10, 2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Добавляем связь тренеров с занятиями
ALTER TABLE classes ADD CONSTRAINT fk_classes_trainer 
    FOREIGN KEY (trainer_id) REFERENCES trainers(id) ON DELETE SET NULL;

-- Персональные тренировки
CREATE TABLE personal_trainings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    trainer_id UUID NOT NULL REFERENCES trainers(id),
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
    duration_minutes INTEGER NOT NULL DEFAULT 60,
    price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled', -- 'scheduled', 'completed', 'cancelled', 'no_show'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (trainer_id, scheduled_at)
);

CREATE INDEX idx_personal_trainings_client ON personal_trainings(client_id);
CREATE INDEX idx_personal_trainings_trainer ON personal_trainings(trainer_id, scheduled_at);

-- ============================================
-- ТЕСТОВЫЕ ДАННЫЕ (для демонстрации)
-- ============================================

INSERT INTO clients (id, full_name, phone, email) VALUES
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'Иванов Иван Иванович', '+79161234567', 'ivanov@example.com'),
    ('b2c3d4e5-f6a7-8901-bcde-f12345678901', 'Петрова Мария Сергеевна', '+79167654321', 'petrova@example.com'),
    ('c3d4e5f6-a7b8-9012-cdef-123456789012', 'Сидоров Алексей Петрович', '+79161112233', 'sidorov@example.com');

INSERT INTO trainers (id, full_name, specialization, rating, hourly_rate) VALUES
    ('t1a1b2c3-d4e5-6789-abcd-ef1234567890', 'Смирнов Дмитрий', 'boxing', 4.8, 2500.00),
    ('t2b2c3d4-e5f6-7890-bcde-f12345678901', 'Козлова Анна', 'yoga', 4.9, 2000.00),
    ('t3c3d4e5-f6a7-8901-cdef-123456789012', 'Волков Сергей', 'judo', 4.7, 2800.00);

INSERT INTO access_cards (id, card_number, client_id, status) VALUES
    ('ac1a1b2c3-d4e5-6789-abcd-ef1234567890', 'RFID-1000000001', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'active'),
    ('ac2b2c3d4-e5f6-7890-bcde-f12345678901', 'RFID-1000000002', 'b2c3d4e5-f6a7-8901-bcde-f12345678901', 'active'),
    ('ac3c3d4e5-f6a7-8901-cdef-123456789012', 'RFID-1000000003', 'c3d4e5f6-a7b8-9012-cdef-123456789012', 'blocked');

INSERT INTO visit_logs (card_id, client_id, entry_time, exit_time, turnstile_id, event_type) VALUES
    ('ac1a1b2c3-d4e5-6789-abcd-ef1234567890', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890', NOW() - INTERVAL '2 hours', NOW() - INTERVAL '30 minutes', 'TS-ENTRANCE-01', 'entry'),
    ('ac2b2c3d4-e5f6-7890-bcde-f12345678901', 'b2c3d4e5-f6a7-8901-bcde-f12345678901', NOW() - INTERVAL '1 hour', NULL, 'TS-ENTRANCE-01', 'entry');

INSERT INTO classes (id, name, class_type, scheduled_at, max_capacity, includes_equipment, trainer_id) VALUES
    ('cl1a1b2c3-d4e5-6789-abcd-ef1234567890', 'Йога для начинающих', 'group', NOW() + INTERVAL '1 day' + INTERVAL '10 hours', 20, FALSE, 't2b2c3d4-e5f6-7890-bcde-f12345678901'),
    ('cl2b2c3d4-e5f6-7890-bcde-f12345678901', 'Бокс: базовая техника', 'martial_arts', NOW() + INTERVAL '1 day' + INTERVAL '19 hours', 15, TRUE, 't1a1b2c3-d4e5-6789-abcd-ef1234567890');

INSERT INTO waitlist (class_id, client_id, position, status) VALUES
    ('cl1a1b2c3-d4e5-6789-abcd-ef1234567890', 'c3d4e5f6-a7b8-9012-cdef-123456789012', 1, 'waiting');

INSERT INTO personal_trainings (client_id, trainer_id, scheduled_at, price, status) VALUES
    ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 't1a1b2c3-d4e5-6789-abcd-ef1234567890', NOW() + INTERVAL '3 days' + INTERVAL '18 hours', 2500.00, 'scheduled');

-- ============================================
-- СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ ДЛЯ API
-- ============================================
CREATE USER api_user WITH PASSWORD 'api_secure_pass_2026';
GRANT CONNECT ON DATABASE silafit TO api_user;
GRANT USAGE ON SCHEMA public TO api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_user;