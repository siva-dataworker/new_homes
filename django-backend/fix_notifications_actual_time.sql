-- Make actual_time nullable for Site Requirement and other non-time-based notifications
ALTER TABLE notifications 
ALTER COLUMN actual_time DROP NOT NULL;

-- Add comment explaining the change
COMMENT ON COLUMN notifications.actual_time IS 'Time related to the notification (nullable for non-time-based notifications like Site Requirements)';
