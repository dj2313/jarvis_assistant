-- ============================================================================
-- Friday ROUTINES TABLE
-- Run this in your Supabase SQL Editor
-- ============================================================================

-- Create routines table
CREATE TABLE IF NOT EXISTS Friday_routines (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    trigger VARCHAR(50) DEFAULT 'manual' NOT NULL,
    trigger_config JSONB DEFAULT '{}',
    actions JSONB DEFAULT '[]' NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_run_at TIMESTAMPTZ
);

-- Create index for faster user queries
CREATE INDEX IF NOT EXISTS idx_Friday_routines_user_id ON Friday_routines(user_id);

-- Enable RLS (Row Level Security)
ALTER TABLE Friday_routines ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own routines
CREATE POLICY "Users can view own routines"
    ON Friday_routines FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can insert their own routines
CREATE POLICY "Users can insert own routines"
    ON Friday_routines FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own routines
CREATE POLICY "Users can update own routines"
    ON Friday_routines FOR UPDATE
    USING (auth.uid() = user_id);

-- Policy: Users can delete their own routines
CREATE POLICY "Users can delete own routines"
    ON Friday_routines FOR DELETE
    USING (auth.uid() = user_id);

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to call the function on update
DROP TRIGGER IF EXISTS update_Friday_routines_updated_at ON Friday_routines;
CREATE TRIGGER update_Friday_routines_updated_at
    BEFORE UPDATE ON Friday_routines
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================================

-- INSERT INTO Friday_routines (user_id, name, description, trigger, trigger_config, actions)
-- VALUES (
--     auth.uid(),
--     'Good Morning',
--     'Start your day with weather, news & calendar',
--     'time',
--     '{"time": "07:00"}',
--     '[
--         {"type": "weather", "label": "Check Weather", "params": {}, "delay_seconds": 0},
--         {"type": "news", "label": "Top Headlines", "params": {}, "delay_seconds": 2},
--         {"type": "calendar", "label": "Today''s Events", "params": {}, "delay_seconds": 2}
--     ]'
-- );
