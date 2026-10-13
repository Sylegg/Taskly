export const backendApiUrl = (process.env.TASKLY_API_URL || 'http://127.0.0.1:8080/api/v1').replace(/\/$/, '');
