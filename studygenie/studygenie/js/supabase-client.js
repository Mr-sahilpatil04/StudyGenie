// StudyGenie Supabase Client Configuration
// This file initializes the Supabase client and provides authentication methods

// Supabase configuration - Replace with your actual values
const SUPABASE_URL = 'your_supabase_url';
const SUPABASE_ANON_KEY = 'your_supabase_anon_key';

// Initialize Supabase client with safety guard for local development
const SUPABASE_ENABLED = typeof window !== 'undefined'
	&& window.supabase
	&& typeof SUPABASE_URL === 'string'
	&& typeof SUPABASE_ANON_KEY === 'string'
	&& /^https?:\/\//i.test(SUPABASE_URL)
	&& !/your_supabase_url/i.test(SUPABASE_URL)
	&& !/your_supabase_anon_key/i.test(SUPABASE_ANON_KEY);

let supabase = null;
if (SUPABASE_ENABLED) {
	try {
		supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
	} catch (e) {
		console.warn('Supabase initialization failed:', e);
	}
}

if (!supabase) {
	console.warn('Supabase not configured. Authentication and API features will be disabled locally.');
	// Minimal no-op stubs to avoid runtime crashes during local development
	supabase = {
		auth: {
			async getSession() { return { data: { session: null }, error: null }; },
			onAuthStateChange(callback) {
				setTimeout(() => callback('SIGNED_OUT', { user: null }), 0);
				return { data: { subscription: { unsubscribe() {} } } };
			},
			async signUp() { return { data: null, error: { message: 'Supabase not configured' } }; },
			async signInWithPassword() { return { data: null, error: { message: 'Supabase not configured' } }; },
			async signOut() { return { error: null }; },
			async signInWithOAuth() { return { data: null, error: { message: 'Supabase not configured' } }; }
		},
		from() {
			const chain = {
				select() { return chain; },
				update() { return chain; },
				insert() { return chain; },
				order() { return chain; },
				eq() { return chain; },
				single: async () => ({ data: null, error: { message: 'Supabase not configured' } })
			};
			return {
				select() { return chain; },
				update() { return chain; },
				insert(values) { return { select() { return { single: async () => ({ data: null, error: { message: 'Supabase not configured' } }) }; } }; },
				order() { return chain; },
				eq() { return chain; }
			};
		},
		storage: {
			from() { return { upload: async () => ({ data: null, error: { message: 'Supabase not configured' } }) }; }
		}
	};
}

// Authentication State Manager
class AuthManager {
    constructor() {
        this.currentUser = null;
        this.userProfile = null;
        this.initializeAuth();
    }

    async initializeAuth() {
        // Check for existing session
        const { data: { session }, error } = await supabase.auth.getSession();
        
        if (session?.user && !error) {
            this.currentUser = session.user;
            await this.loadUserProfile();
            this.updateUIForAuthenticatedUser();
        } else {
            this.updateUIForUnauthenticatedUser();
        }

        // Listen for auth changes
        supabase.auth.onAuthStateChange(async (event, session) => {
            console.log('Auth state changed:', event, session);
            
            if (session?.user) {
                this.currentUser = session.user;
                await this.loadUserProfile();
                this.updateUIForAuthenticatedUser();
                
                if (event === 'SIGNED_IN') {
                    // Redirect to dashboard after successful login/registration
                    window.location.href = '/pages/dashboard.html';
                }
            } else {
                this.currentUser = null;
                this.userProfile = null;
                this.updateUIForUnauthenticatedUser();
            }
        });
    }

    async signUp(email, password, userData = {}) {
        try {
            const { data, error } = await supabase.auth.signUp({
                email: email,
                password: password,
                options: {
                    data: {
                        full_name: userData.fullName || '',
                        academic_level: userData.academicLevel || 'undergraduate',
                        role: 'student'
                    }
                }
            });

            if (error) throw error;

            // Show success message
            this.showMessage('Registration successful! Please check your email for verification.', 'success');
            return { success: true, data };

        } catch (error) {
            console.error('Sign up error:', error);
            this.showMessage(error.message, 'error');
            return { success: false, error };
        }
    }

    async signIn(email, password) {
        try {
            const { data, error } = await supabase.auth.signInWithPassword({
                email: email,
                password: password
            });

            if (error) throw error;

            return { success: true, data };

        } catch (error) {
            console.error('Sign in error:', error);
            this.showMessage(error.message, 'error');
            return { success: false, error };
        }
    }

    async signOut() {
        try {
            const { error } = await supabase.auth.signOut();
            if (error) throw error;
            
            // Redirect to landing page
            window.location.href = '/pages/landing_page_with_authentication.html';
            
        } catch (error) {
            console.error('Sign out error:', error);
            this.showMessage(error.message, 'error');
        }
    }

    async signInWithProvider(provider) {
        try {
            const { data, error } = await supabase.auth.signInWithOAuth({
                provider: provider,
                options: {
                    redirectTo: `${window.location.origin}/pages/dashboard.html`
                }
            });

            if (error) throw error;

            return { success: true, data };

        } catch (error) {
            console.error(`${provider} sign in error:`, error);
            this.showMessage(error.message, 'error');
            return { success: false, error };
        }
    }

    async loadUserProfile() {
        if (!this.currentUser) return;

        try {
            const { data, error } = await supabase
                .from('user_profiles')
                .select('*')
                .eq('id', this.currentUser.id)
                .single();

            if (error) throw error;

            this.userProfile = data;
            return data;

        } catch (error) {
            console.error('Error loading user profile:', error);
            return null;
        }
    }

    async updateUserProfile(updates) {
        if (!this.currentUser) return { success: false, error: 'Not authenticated' };

        try {
            const { data, error } = await supabase
                .from('user_profiles')
                .update({
                    ...updates,
                    updated_at: new Date().toISOString()
                })
                .eq('id', this.currentUser.id)
                .select()
                .single();

            if (error) throw error;

            this.userProfile = data;
            this.showMessage('Profile updated successfully!', 'success');
            return { success: true, data };

        } catch (error) {
            console.error('Error updating profile:', error);
            this.showMessage(error.message, 'error');
            return { success: false, error };
        }
    }

    updateUIForAuthenticatedUser() {
        // Hide login/register buttons
        const loginBtns = document.querySelectorAll('#loginBtn, #mobileLoginBtn');
        const registerBtns = document.querySelectorAll('#registerBtn, #mobileRegisterBtn, #heroRegisterBtn');
        
        loginBtns.forEach(btn => btn.style.display = 'none');
        registerBtns.forEach(btn => btn.style.display = 'none');

        // Show user info or logout button
        this.createUserMenu();
    }

    updateUIForUnauthenticatedUser() {
        // Show login/register buttons
        const loginBtns = document.querySelectorAll('#loginBtn, #mobileLoginBtn');
        const registerBtns = document.querySelectorAll('#registerBtn, #mobileRegisterBtn, #heroRegisterBtn');
        
        loginBtns.forEach(btn => btn.style.display = 'block');
        registerBtns.forEach(btn => btn.style.display = 'block');

        // Remove user menu if exists
        const existingMenu = document.getElementById('userMenu');
        if (existingMenu) {
            existingMenu.remove();
        }
    }

    createUserMenu() {
        // Remove existing menu
        const existingMenu = document.getElementById('userMenu');
        if (existingMenu) {
            existingMenu.remove();
        }

        // Create user menu
        const userMenu = document.createElement('div');
        userMenu.id = 'userMenu';
        userMenu.className = 'flex items-center space-x-3';
        
        const userName = this.userProfile?.full_name || this.currentUser?.email?.split('@')[0] || 'User';
        const userXP = this.userProfile?.xp_points || 0;
        
        userMenu.innerHTML = `
            <div class="hidden md:flex items-center space-x-3">
                <div class="text-sm text-text-secondary">
                    <div class="font-medium text-text-primary">${userName}</div>
                    <div class="text-xs">XP: ${userXP}</div>
                </div>
                ${this.userProfile?.avatar_url ? 
                    `<img src="${this.userProfile.avatar_url}" alt="Profile" class="w-8 h-8 rounded-full">` :
                    `<div class="w-8 h-8 rounded-full bg-primary-100 flex items-center justify-center">
                        <span class="text-primary text-sm font-medium">${userName.charAt(0).toUpperCase()}</span>
                    </div>`
                }
                <button id="logoutBtn" class="px-3 py-1 text-sm text-text-secondary hover:text-primary transition-colors">
                    Logout
                </button>
            </div>
        `;

        // Insert menu into navigation
        const desktopNav = document.querySelector('header nav .hidden.md\\:flex');
        if (desktopNav) {
            desktopNav.appendChild(userMenu);
            
            // Add logout functionality
            const logoutBtn = document.getElementById('logoutBtn');
            if (logoutBtn) {
                logoutBtn.addEventListener('click', () => this.signOut());
            }
        }
    }

    showMessage(message, type = 'info') {
        // Create toast notification
        const toast = document.createElement('div');
        toast.className = `fixed top-4 right-4 z-50 px-6 py-3 rounded-lg text-white font-medium transform transition-all duration-300 translate-x-full`;
        
        // Set color based on type
        switch (type) {
            case 'success':
                toast.className += ' bg-green-500';
                break;
            case 'error':
                toast.className += ' bg-red-500';
                break;
            case 'warning':
                toast.className += ' bg-yellow-500';
                break;
            default:
                toast.className += ' bg-blue-500';
        }
        
        toast.textContent = message;
        document.body.appendChild(toast);

        // Animate in
        setTimeout(() => {
            toast.classList.remove('translate-x-full');
        }, 100);

        // Remove after 5 seconds
        setTimeout(() => {
            toast.classList.add('translate-x-full');
            setTimeout(() => {
                document.body.removeChild(toast);
            }, 300);
        }, 5000);
    }

    // Utility methods
    isAuthenticated() {
        return !!this.currentUser;
    }

    getCurrentUser() {
        return this.currentUser;
    }

    getUserProfile() {
        return this.userProfile;
    }

    hasRole(role) {
        return this.userProfile?.role === role;
    }

    // Protected route helper
    requireAuth() {
        if (!this.isAuthenticated()) {
            window.location.href = '/pages/landing_page_with_authentication.html';
            return false;
        }
        return true;
    }
}

// StudyGenie API Helper Class
class StudyGenieAPI {
    constructor(authManager) {
        this.auth = authManager;
    }

    // Study Materials
    async uploadStudyMaterial(file, title, description, materialType) {
        if (!this.auth.isAuthenticated()) {
            throw new Error('Authentication required');
        }

        try {
            // Upload file to storage
            const fileExt = file.name.split('.').pop();
            const fileName = `${Date.now()}.${fileExt}`;
            const filePath = `${this.auth.currentUser.id}/${fileName}`;

            const { data: uploadData, error: uploadError } = await supabase.storage
                .from('study-materials')
                .upload(filePath, file);

            if (uploadError) throw uploadError;

            // Create database record
            const { data, error } = await supabase
                .from('study_materials')
                .insert({
                    user_id: this.auth.currentUser.id,
                    title: title,
                    description: description,
                    file_path: filePath,
                    material_type: materialType,
                    processing_status: 'pending'
                })
                .select()
                .single();

            if (error) throw error;

            return { success: true, data };

        } catch (error) {
            console.error('Upload error:', error);
            return { success: false, error };
        }
    }

    async getStudyMaterials() {
        if (!this.auth.isAuthenticated()) return [];

        try {
            const { data, error } = await supabase
                .from('study_materials')
                .select('*')
                .eq('user_id', this.auth.currentUser.id)
                .order('created_at', { ascending: false });

            if (error) throw error;
            return data || [];

        } catch (error) {
            console.error('Error fetching study materials:', error);
            return [];
        }
    }

    // Generated Content
    async getGeneratedContent(materialId = null, contentType = null) {
        if (!this.auth.isAuthenticated()) return [];

        try {
            let query = supabase
                .from('generated_content')
                .select('*')
                .eq('user_id', this.auth.currentUser.id);

            if (materialId) query = query.eq('material_id', materialId);
            if (contentType) query = query.eq('content_type', contentType);

            const { data, error } = await query.order('created_at', { ascending: false });

            if (error) throw error;
            return data || [];

        } catch (error) {
            console.error('Error fetching generated content:', error);
            return [];
        }
    }

    // Quizzes
    async createQuiz(materialId, title, description, quizType, questions) {
        if (!this.auth.isAuthenticated()) {
            throw new Error('Authentication required');
        }

        try {
            const { data, error } = await supabase
                .from('quizzes')
                .insert({
                    user_id: this.auth.currentUser.id,
                    material_id: materialId,
                    title: title,
                    description: description,
                    quiz_type: quizType,
                    questions: { questions }
                })
                .select()
                .single();

            if (error) throw error;
            return { success: true, data };

        } catch (error) {
            console.error('Error creating quiz:', error);
            return { success: false, error };
        }
    }

    async submitQuizAttempt(quizId, answers, timeTaken) {
        if (!this.auth.isAuthenticated()) {
            throw new Error('Authentication required');
        }

        try {
            // Calculate score (simplified - you'd implement proper scoring logic)
            const score = Math.floor(Math.random() * 100); // Placeholder

            const { data, error } = await supabase
                .from('quiz_attempts')
                .insert({
                    user_id: this.auth.currentUser.id,
                    quiz_id: quizId,
                    answers: { answers },
                    score: score,
                    time_taken: timeTaken
                })
                .select()
                .single();

            if (error) throw error;

            // Update user progress
            await this.updateUserProgress(score * 2); // 2 XP per point
            
            return { success: true, data };

        } catch (error) {
            console.error('Error submitting quiz attempt:', error);
            return { success: false, error };
        }
    }

    // Progress Tracking
    async recordStudySession(materialId, sessionType, duration) {
        if (!this.auth.isAuthenticated()) return;

        try {
            const xpEarned = Math.floor(duration / 60); // 1 XP per minute

            const { data, error } = await supabase
                .from('study_sessions')
                .insert({
                    user_id: this.auth.currentUser.id,
                    material_id: materialId,
                    session_type: sessionType,
                    duration: duration,
                    xp_earned: xpEarned,
                    completed_at: new Date().toISOString()
                })
                .select()
                .single();

            if (error) throw error;

            // Update user progress
            await this.updateUserProgress(xpEarned);
            
            return data;

        } catch (error) {
            console.error('Error recording study session:', error);
        }
    }

    async updateUserProgress(xpToAdd) {
        if (!this.auth.isAuthenticated()) return;

        try {
            // Call the database function
            const { error } = await supabase.rpc('update_user_progress', {
                user_uuid: this.auth.currentUser.id,
                xp_to_add: xpToAdd
            });

            if (error) throw error;

            // Refresh user profile
            await this.auth.loadUserProfile();

            // Check for new achievements
            await supabase.rpc('check_achievements', {
                user_uuid: this.auth.currentUser.id
            });

        } catch (error) {
            console.error('Error updating user progress:', error);
        }
    }

    // Analytics
    async getLearningAnalytics(days = 30) {
        if (!this.auth.isAuthenticated()) return [];

        try {
            const fromDate = new Date();
            fromDate.setDate(fromDate.getDate() - days);

            const { data, error } = await supabase
                .from('learning_analytics')
                .select('*')
                .eq('user_id', this.auth.currentUser.id)
                .gte('date', fromDate.toISOString().split('T')[0])
                .order('date', { ascending: false });

            if (error) throw error;
            return data || [];

        } catch (error) {
            console.error('Error fetching analytics:', error);
            return [];
        }
    }

    // Achievements
    async getUserAchievements() {
        if (!this.auth.isAuthenticated()) return [];

        try {
            const { data, error } = await supabase
                .from('user_achievements')
                .select(`
                    *,
                    achievements (
                        name,
                        description,
                        icon,
                        xp_reward,
                        category
                    )
                `)
                .eq('user_id', this.auth.currentUser.id)
                .order('earned_at', { ascending: false });

            if (error) throw error;
            return data || [];

        } catch (error) {
            console.error('Error fetching user achievements:', error);
            return [];
        }
    }
}

// Initialize global instances
const authManager = new AuthManager();
const studyGenieAPI = new StudyGenieAPI(authManager);

// Make them globally available
window.authManager = authManager;
window.studyGenieAPI = studyGenieAPI;
window.supabaseClient = supabase;