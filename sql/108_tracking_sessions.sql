-- Migration: Create tracking_sessions table for provider location tracking
-- Description: Stores active and historical tracking sessions for customer-provider engagements
-- Author: Tracking Service
-- Date: 2026-07-05
-- Dependencies: Requires engagements table (baseline)

-- Create tracking_sessions table
CREATE TABLE IF NOT EXISTS tracking_sessions (
    session_id VARCHAR(255) PRIMARY KEY,
    engagement_id INTEGER NOT NULL,
    customer_id INTEGER NOT NULL,
    provider_id INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_update_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    destination JSONB NOT NULL,
    is_team BOOLEAN DEFAULT FALSE,
    team_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_tracking_sessions_engagement_id 
    ON tracking_sessions(engagement_id);

CREATE INDEX IF NOT EXISTS idx_tracking_sessions_customer_id 
    ON tracking_sessions(customer_id);

CREATE INDEX IF NOT EXISTS idx_tracking_sessions_provider_id 
    ON tracking_sessions(provider_id);

CREATE INDEX IF NOT EXISTS idx_tracking_sessions_status 
    ON tracking_sessions(status);

CREATE INDEX IF NOT EXISTS idx_tracking_sessions_started_at 
    ON tracking_sessions(started_at DESC);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_tracking_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_tracking_sessions_updated_at
    BEFORE UPDATE ON tracking_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_tracking_sessions_updated_at();

-- Add comments for documentation
COMMENT ON TABLE tracking_sessions IS 'Stores real-time tracking sessions for service provider location tracking';
COMMENT ON COLUMN tracking_sessions.session_id IS 'Unique session identifier (UUID or generated ID)';
COMMENT ON COLUMN tracking_sessions.engagement_id IS 'Reference to the engagement/booking being tracked';
COMMENT ON COLUMN tracking_sessions.customer_id IS 'Customer who is tracking the provider';
COMMENT ON COLUMN tracking_sessions.provider_id IS 'Provider being tracked';
COMMENT ON COLUMN tracking_sessions.status IS 'Session status: active, offline_estimated, completed';
COMMENT ON COLUMN tracking_sessions.started_at IS 'When tracking session started';
COMMENT ON COLUMN tracking_sessions.last_update_at IS 'Last time location update was received';
COMMENT ON COLUMN tracking_sessions.completed_at IS 'When tracking session ended';
COMMENT ON COLUMN tracking_sessions.destination IS 'Service destination address (latitude, longitude, address)';
COMMENT ON COLUMN tracking_sessions.is_team IS 'Whether this is a team service (multiple providers)';
COMMENT ON COLUMN tracking_sessions.team_data IS 'Team information (lead_provider_id, member_ids, member_count)';
