-- Migration: Create engagement_tracking_status table for provider journey tracking
-- Description: Separate tracking status from task_status to avoid interfering with existing workflow
-- Author: Tracking Service
-- Date: 2026-07-05
-- Dependencies: Requires engagements table (baseline)

-- Create engagement_tracking_status table
CREATE TABLE IF NOT EXISTS engagement_tracking_status (
    engagement_id INTEGER PRIMARY KEY REFERENCES engagements(engagement_id) ON DELETE CASCADE,
    provider_id INTEGER NOT NULL,
    tracking_status VARCHAR(50) NOT NULL DEFAULT 'not_started',
    -- Tracking status values:
    -- 'not_started': Provider hasn't begun journey
    -- 'en_route': Provider is traveling to customer location (TRACKING ENABLED)
    -- 'arrived': Provider has reached customer location
    -- 'service_started': Service is in progress
    -- 'service_completed': Service finished
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    last_location_update TIMESTAMP WITH TIME ZONE,
    journey_started_at TIMESTAMP WITH TIME ZONE,
    arrived_at TIMESTAMP WITH TIME ZONE,
    service_started_at TIMESTAMP WITH TIME ZONE,
    service_completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_tracking_status_provider_id 
    ON engagement_tracking_status(provider_id);

CREATE INDEX IF NOT EXISTS idx_tracking_status_tracking_status 
    ON engagement_tracking_status(tracking_status);

CREATE INDEX IF NOT EXISTS idx_tracking_status_en_route
    ON engagement_tracking_status(tracking_status)
    WHERE tracking_status = 'en_route';

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_tracking_status_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_tracking_status_updated_at
    BEFORE UPDATE ON engagement_tracking_status
    FOR EACH ROW
    EXECUTE FUNCTION update_tracking_status_updated_at();

-- Add comments for documentation
COMMENT ON TABLE engagement_tracking_status IS 'Provider journey tracking status - separate from task_status to avoid workflow interference';
COMMENT ON COLUMN engagement_tracking_status.tracking_status IS 'Current tracking status: not_started, en_route, arrived, service_started, service_completed';
COMMENT ON COLUMN engagement_tracking_status.journey_started_at IS 'When provider started traveling (tracking begins)';
COMMENT ON COLUMN engagement_tracking_status.arrived_at IS 'When provider reached customer location';
COMMENT ON COLUMN engagement_tracking_status.service_started_at IS 'When provider began service work';
COMMENT ON COLUMN engagement_tracking_status.service_completed_at IS 'When provider finished service';
