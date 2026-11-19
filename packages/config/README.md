# Configuration

Development configuration is injected from the ignored root `.env`; `.env.example` contains names and placeholders. Never embed provider certificates, database URLs or test access keys in source control. Flutter receives the public API base URL only and obtains short-lived participant RTC tokens from NestJS.
