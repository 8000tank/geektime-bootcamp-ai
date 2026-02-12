-- Interview Management Database (PostgreSQL Version)
-- 面试管理数据库：记录公司招聘、面试安排、面试结果等信息

-- 1. 部门表
CREATE TABLE departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    manager_name VARCHAR(100),
    location VARCHAR(100),
    budget DECIMAL(15, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_departments_code ON departments(code);

-- 2. 职位表
CREATE TABLE job_positions (
    id SERIAL PRIMARY KEY,
    department_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    job_code VARCHAR(50) NOT NULL UNIQUE,
    level VARCHAR(50) NOT NULL,
    employment_type VARCHAR(50) NOT NULL,
    min_salary DECIMAL(12, 2),
    max_salary DECIMAL(12, 2),
    headcount INT DEFAULT 1,
    status VARCHAR(50) DEFAULT 'OPEN',
    required_skills TEXT,
    preferred_skills TEXT,
    description TEXT,
    posted_date DATE,
    close_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (department_id) REFERENCES departments(id)
);
CREATE INDEX idx_job_positions_status ON job_positions(status);
CREATE INDEX idx_job_positions_department ON job_positions(department_id);
CREATE INDEX idx_job_positions_job_code ON job_positions(job_code);

-- 3. 候选人表
CREATE TABLE candidates (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(200) NOT NULL UNIQUE,
    phone VARCHAR(50),
    current_company VARCHAR(200),
    current_title VARCHAR(200),
    years_of_experience DECIMAL(4, 2),
    education_level VARCHAR(50),
    university VARCHAR(200),
    major VARCHAR(200),
    resume_url VARCHAR(500),
    linkedin_url VARCHAR(500),
    github_url VARCHAR(500),
    source VARCHAR(100),
    status VARCHAR(50) DEFAULT 'ACTIVE',
    location VARCHAR(200),
    expected_salary DECIMAL(12, 2),
    notice_period_days INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_candidates_email ON candidates(email);
CREATE INDEX idx_candidates_status ON candidates(status);
CREATE INDEX idx_candidates_source ON candidates(source);

-- 4. 职位申请表
CREATE TABLE applications (
    id SERIAL PRIMARY KEY,
    candidate_id INT NOT NULL,
    job_position_id INT NOT NULL,
    application_date DATE NOT NULL,
    status VARCHAR(50) DEFAULT 'PENDING',
    current_stage VARCHAR(100),
    resume_version VARCHAR(50),
    cover_letter TEXT,
    referrer_name VARCHAR(100),
    priority VARCHAR(50) DEFAULT 'MEDIUM',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (candidate_id) REFERENCES candidates(id),
    FOREIGN KEY (job_position_id) REFERENCES job_positions(id),
    UNIQUE (candidate_id, job_position_id)
);
CREATE INDEX idx_applications_status ON applications(status);
CREATE INDEX idx_applications_candidate ON applications(candidate_id);
CREATE INDEX idx_applications_job ON applications(job_position_id);
CREATE INDEX idx_applications_date ON applications(application_date);

-- 5. 面试官表
CREATE TABLE interviewers (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(200) NOT NULL UNIQUE,
    department_id INT,
    title VARCHAR(200),
    expertise TEXT,
    interview_count INT DEFAULT 0,
    avg_rating DECIMAL(3, 2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (department_id) REFERENCES departments(id)
);
CREATE INDEX idx_interviewers_email ON interviewers(email);
CREATE INDEX idx_interviewers_department ON interviewers(department_id);
CREATE INDEX idx_interviewers_active ON interviewers(is_active);

-- 6. 面试轮次配置表
CREATE TABLE interview_rounds (
    id SERIAL PRIMARY KEY,
    job_position_id INT NOT NULL,
    round_number INT NOT NULL,
    round_name VARCHAR(100) NOT NULL,
    round_type VARCHAR(50) NOT NULL,
    duration_minutes INT DEFAULT 60,
    is_required BOOLEAN DEFAULT TRUE,
    description TEXT,
    evaluation_criteria TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (job_position_id) REFERENCES job_positions(id),
    UNIQUE (job_position_id, round_number)
);
CREATE INDEX idx_interview_rounds_job_position ON interview_rounds(job_position_id);

-- 7. 面试安排表
CREATE TABLE interviews (
    id SERIAL PRIMARY KEY,
    application_id INT NOT NULL,
    interview_round_id INT NOT NULL,
    scheduled_date DATE NOT NULL,
    scheduled_time TIME NOT NULL,
    end_time TIME,
    timezone VARCHAR(50) DEFAULT 'Asia/Shanghai',
    interview_type VARCHAR(50) NOT NULL,
    location VARCHAR(200),
    meeting_link VARCHAR(500),
    status VARCHAR(50) DEFAULT 'SCHEDULED',
    cancellation_reason TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES applications(id),
    FOREIGN KEY (interview_round_id) REFERENCES interview_rounds(id)
);
CREATE INDEX idx_interviews_application ON interviews(application_id);
CREATE INDEX idx_interviews_round ON interviews(interview_round_id);
CREATE INDEX idx_interviews_scheduled_date ON interviews(scheduled_date);
CREATE INDEX idx_interviews_status ON interviews(status);

-- 8. 面试官分配表
CREATE TABLE interview_assignments (
    id SERIAL PRIMARY KEY,
    interview_id INT NOT NULL,
    interviewer_id INT NOT NULL,
    role VARCHAR(50) DEFAULT 'INTERVIEWER',
    confirmed BOOLEAN DEFAULT FALSE,
    feedback_submitted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interview_id) REFERENCES interviews(id),
    FOREIGN KEY (interviewer_id) REFERENCES interviewers(id),
    UNIQUE (interview_id, interviewer_id)
);
CREATE INDEX idx_interview_assignments_interview ON interview_assignments(interview_id);
CREATE INDEX idx_interview_assignments_interviewer ON interview_assignments(interviewer_id);

-- 9. 面试反馈表
CREATE TABLE interview_feedback (
    id SERIAL PRIMARY KEY,
    interview_id INT NOT NULL,
    interviewer_id INT NOT NULL,
    overall_rating INT CHECK (overall_rating BETWEEN 1 AND 5),
    technical_skills_rating INT CHECK (technical_skills_rating BETWEEN 1 AND 5),
    communication_rating INT CHECK (communication_rating BETWEEN 1 AND 5),
    problem_solving_rating INT CHECK (problem_solving_rating BETWEEN 1 AND 5),
    cultural_fit_rating INT CHECK (cultural_fit_rating BETWEEN 1 AND 5),
    recommendation VARCHAR(50) NOT NULL,
    strengths TEXT,
    weaknesses TEXT,
    detailed_feedback TEXT,
    questions_asked TEXT,
    candidate_questions TEXT,
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (interview_id) REFERENCES interviews(id),
    FOREIGN KEY (interviewer_id) REFERENCES interviewers(id)
);
CREATE INDEX idx_interview_feedback_interview ON interview_feedback(interview_id);
CREATE INDEX idx_interview_feedback_interviewer ON interview_feedback(interviewer_id);
CREATE INDEX idx_interview_feedback_rating ON interview_feedback(overall_rating);
CREATE INDEX idx_interview_feedback_recommendation ON interview_feedback(recommendation);

-- 10. Offer表
CREATE TABLE offers (
    id SERIAL PRIMARY KEY,
    application_id INT NOT NULL,
    offer_date DATE NOT NULL,
    expiry_date DATE NOT NULL,
    base_salary DECIMAL(12, 2) NOT NULL,
    bonus DECIMAL(12, 2),
    equity_shares INT,
    sign_on_bonus DECIMAL(12, 2),
    relocation_package DECIMAL(12, 2),
    benefits_package TEXT,
    start_date DATE,
    status VARCHAR(50) DEFAULT 'PENDING',
    response_date DATE,
    rejection_reason TEXT,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES applications(id)
);
CREATE INDEX idx_offers_application ON offers(application_id);
CREATE INDEX idx_offers_status ON offers(status);
CREATE INDEX idx_offers_offer_date ON offers(offer_date);

-- 11. 背景调查表
CREATE TABLE background_checks (
    id SERIAL PRIMARY KEY,
    application_id INT NOT NULL,
    check_type VARCHAR(100) NOT NULL,
    vendor VARCHAR(200),
    initiated_date DATE NOT NULL,
    completed_date DATE,
    status VARCHAR(50) DEFAULT 'PENDING',
    result VARCHAR(50),
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES applications(id)
);
CREATE INDEX idx_background_checks_application ON background_checks(application_id);
CREATE INDEX idx_background_checks_status ON background_checks(status);

-- 12. 活动日志表
CREATE TABLE activity_logs (
    id SERIAL PRIMARY KEY,
    application_id INT,
    interview_id INT,
    activity_type VARCHAR(100) NOT NULL,
    actor_name VARCHAR(200),
    actor_email VARCHAR(200),
    description TEXT,
    old_value VARCHAR(500),
    new_value VARCHAR(500),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES applications(id),
    FOREIGN KEY (interview_id) REFERENCES interviews(id)
);
CREATE INDEX idx_activity_logs_application ON activity_logs(application_id);
CREATE INDEX idx_activity_logs_interview ON activity_logs(interview_id);
CREATE INDEX idx_activity_logs_activity_type ON activity_logs(activity_type);
CREATE INDEX idx_activity_logs_created_at ON activity_logs(created_at);

-- 插入示例数据
INSERT INTO departments (name, code, manager_name, location, budget) VALUES
('Engineering', 'ENG', 'Alice Johnson', 'Beijing', 500000.00),
('Product', 'PRD', 'Bob Smith', 'Shanghai', 300000.00),
('Design', 'DES', 'Carol White', 'Shenzhen', 200000.00);

INSERT INTO job_positions (department_id, title, job_code, level, employment_type, min_salary, max_salary, headcount, status, required_skills, posted_date) VALUES
(1, 'Senior Backend Engineer', 'ENG-001', 'Senior', 'Full-time', 300000, 500000, 2, 'OPEN', 'Python, PostgreSQL, Redis', '2024-01-01'),
(1, 'Frontend Engineer', 'ENG-002', 'Mid', 'Full-time', 200000, 350000, 1, 'OPEN', 'React, TypeScript, CSS', '2024-01-05'),
(2, 'Product Manager', 'PRD-001', 'Senior', 'Full-time', 250000, 400000, 1, 'OPEN', 'Product Strategy, Data Analysis', '2024-01-10');

INSERT INTO candidates (first_name, last_name, email, phone, current_company, current_title, years_of_experience, education_level, university, source, location, expected_salary) VALUES
('张', '三', 'zhangsan@example.com', '13800138000', 'TechCorp', 'Backend Engineer', 5.5, 'Bachelor', '清华大学', 'LinkedIn', '北京', 400000),
('李', '四', 'lisi@example.com', '13900139000', 'StartupXYZ', 'Full Stack Developer', 3.0, 'Master', '北京大学', 'Referral', '上海', 300000),
('王', '五', 'wangwu@example.com', '13700137000', 'BigTech', 'Product Manager', 7.0, 'Master', '复旦大学', 'Job Board', '深圳', 350000);

INSERT INTO applications (candidate_id, job_position_id, application_date, status, priority) VALUES
(1, 1, '2024-01-15', 'INTERVIEW', 'HIGH'),
(2, 2, '2024-01-18', 'SCREENING', 'MEDIUM'),
(3, 3, '2024-01-20', 'PENDING', 'MEDIUM');
