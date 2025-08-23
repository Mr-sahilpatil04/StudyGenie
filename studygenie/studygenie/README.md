# StudyGenie - AI-Powered Learning Platform

StudyGenie is a comprehensive educational platform that transforms study materials into interactive learning experiences using AI. Built with HTML, CSS, JavaScript, and powered by Supabase for backend services.

## ✨ Features

### 🔐 Authentication & User Management
- Email/password authentication with Supabase Auth
- Social login (Google, Microsoft)
- User profiles with academic levels and roles
- Email verification and password recovery

### 📚 Study Material Processing
- Upload PDFs, images, and handwritten notes
- OCR text extraction from images
- AI-powered content analysis and processing
- Secure file storage with Supabase Storage

### 🧠 AI-Powered Content Generation
- Automatic summaries in multiple difficulty levels
- AI-generated flashcards for spaced repetition
- Custom quizzes based on study materials
- Personalized explanations (kid-friendly, simple, exam-mode)

### 🎮 Gamification & Progress Tracking
- XP points and achievement system
- Study streaks and progress analytics
- Leaderboards and badges
- Personalized learning paths

### 📊 Analytics & Insights
- Learning progress tracking
- Performance analytics
- Study time and material processing stats
- Quiz scores and improvement trends

### 🃏 Spaced Repetition System
- Smart flashcard scheduling
- Difficulty-based review intervals
- Performance-adaptive algorithms
- Long-term retention optimization

## 🚀 Quick Start

### Prerequisites
- Modern web browser with JavaScript enabled
- Supabase account and project
- Web server (for local development)

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd studygenie
```

2. **Install dependencies**
```bash
npm install
```

3. **Setup Supabase**
   - Create a new project at [supabase.com](https://supabase.com)
   - Go to Project Settings > API
   - Copy your Project URL and anon/public key

4. **Configure Supabase credentials**
   - Open `js/supabase-client.js`
   - Replace the placeholder values:
```javascript
const SUPABASE_URL = 'your_supabase_url';
const SUPABASE_ANON_KEY = 'your_supabase_anon_key';
```

5. **Run database migrations**
   - Go to your Supabase dashboard
   - Navigate to SQL Editor
   - Run the migration file: `supabase/migrations/20250122195142_studygenie_full_integration.sql`

6. **Start development server**
```bash
npm run dev
```

7. **Open the application**
   - Open `pages/landing_page_with_authentication.html` in your browser
   - Or serve the files using a local web server

## 📁 Project Structure

```
studygenie/
├── css/
│   ├── main.css (generated - don't edit)
│   └── tailwind.css (source CSS file)
├── js/
│   └── supabase-client.js (Supabase client & API helpers)
├── pages/
│   ├── dashboard.html (main dashboard)
│   ├── landing_page_with_authentication.html (login/register)
│   ├── material_upload_and_processing.html (file uploads)
│   ├── quiz_and_assessment_center.html (quizzes)
│   └── progress_analytics_dashboard.html (analytics)
├── public/
│   ├── favicon.ico
│   ├── manifest.json
│   └── dhws-data-injector.js
├── supabase/
│   └── migrations/
│       └── 20250122195142_studygenie_full_integration.sql
├── index.html (main entry point)
├── package.json
└── README.md
```

## 🎯 Core Components

### Authentication Manager (`js/supabase-client.js`)
Handles all authentication operations:
- Sign up/sign in with email
- Social authentication
- Session management
- User profile loading
- UI updates based on auth state

### StudyGenie API (`js/supabase-client.js`)
Provides methods for:
- Study material uploads
- Content generation
- Quiz management
- Progress tracking
- Analytics retrieval

### Database Schema
Complete schema includes:
- User profiles and authentication
- Study materials and file storage
- Generated content (summaries, flashcards, quizzes)
- Progress tracking and analytics
- Gamification (achievements, XP, streaks)
- Spaced repetition system

## 🔧 Configuration

### Environment Variables
Set these in your `js/supabase-client.js`:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anon/public key

### Storage Buckets
The application uses two storage buckets:
- `study-materials`: Private bucket for user files (50MB limit)
- `profile-images`: Public bucket for avatars (5MB limit)

### Authentication Providers
To enable social login:
1. Go to Supabase Dashboard > Authentication > Providers
2. Enable and configure Google/Microsoft OAuth
3. Add your domain to allowed origins

## 🛡️ Security Features

### Row Level Security (RLS)
- All tables have RLS policies enabled
- Users can only access their own data
- Admins have elevated permissions
- Storage files are user-scoped

### Input Validation
- Client-side form validation
- Server-side data constraints
- File type and size limits
- SQL injection prevention

### Data Privacy
- User data isolation
- Secure file storage
- Encrypted passwords
- GDPR compliance ready

## 🎮 Gamification System

### XP Points
- Reading materials: 1 XP per minute
- Quiz completion: 2 XP per point scored
- Achievement unlocks: Variable XP rewards

### Achievements
Pre-configured achievements include:
- First Steps (upload first material)
- Study Buddy (complete first quiz)
- Rising Star (earn 500 XP)
- Consistent Learner (7-day streak)
- Quiz Master (90% on 5 quizzes)

### Study Streaks
- Daily study tracking
- Streak maintenance logic
- Longest streak records
- Streak-based achievements

## 📊 Analytics & Reporting

### User Analytics
- Daily study time tracking
- Materials processed count
- Quiz performance metrics
- XP and achievement progress

### Learning Insights
- Performance trends over time
- Subject matter proficiency
- Study habit analysis
- Recommendation engine data

## 🔄 API Reference

### Authentication
```javascript
// Sign up new user
await authManager.signUp(email, password, userData);

// Sign in existing user
await authManager.signIn(email, password);

// Sign out
await authManager.signOut();

// Update profile
await authManager.updateUserProfile(updates);
```

### Study Materials
```javascript
// Upload study material
await studyGenieAPI.uploadStudyMaterial(file, title, description, type);

// Get user's materials
await studyGenieAPI.getStudyMaterials();

// Get generated content
await studyGenieAPI.getGeneratedContent(materialId, contentType);
```

### Progress Tracking
```javascript
// Record study session
await studyGenieAPI.recordStudySession(materialId, sessionType, duration);

// Update user progress
await studyGenieAPI.updateUserProgress(xpToAdd);

// Get analytics
await studyGenieAPI.getLearningAnalytics(days);
```

## 🚀 Deployment

### Prerequisites for Production
1. Domain name and SSL certificate
2. Production Supabase project
3. Configured authentication providers
4. CDN for static assets (optional)

### Deployment Steps
1. Build the project: `npm run build:css`
2. Upload files to your web server
3. Update Supabase URLs in production environment
4. Configure domain in Supabase settings
5. Test authentication flows

### Performance Optimization
- Enable Tailwind CSS purging for production
- Compress images and assets
- Use CDN for Supabase client library
- Implement caching strategies

## 🧪 Development

### Local Development
```bash
# Install dependencies
npm install

# Start development mode (CSS watching)
npm run dev

# Build CSS for production
npm run build:css
```

### Testing
- Test authentication flows
- Verify file upload functionality
- Check RLS policies
- Test responsive design

### Database Development
```sql
-- Clean up test data (development only)
SELECT public.cleanup_studygenie_data();

-- Check user progress
SELECT * FROM public.user_profiles WHERE email = 'test@example.com';

-- View analytics
SELECT * FROM public.learning_analytics WHERE user_id = 'user-id';
```

## 📚 Learning Resources

### Supabase Documentation
- [Supabase Docs](https://supabase.com/docs)
- [JavaScript Client](https://supabase.com/docs/reference/javascript)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

### Development Tools
- [Tailwind CSS](https://tailwindcss.com/docs)
- [Supabase Dashboard](https://app.supabase.com)
- [Browser DevTools](https://developer.chrome.com/docs/devtools/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Check the documentation
- Review Supabase logs in dashboard
- Open an issue on GitHub
- Contact the development team

---

**StudyGenie** - Transform your learning experience with AI-powered personalization! 🎓✨