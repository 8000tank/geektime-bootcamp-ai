# MotherDuck Frontend Design Rules

## 1. 核心设计理念 (Design Philosophy)

*   **工业感与趣味性结合**：深色背景代表“硬核/底层技术”，高亮黄色代表“能量/速度”，像素风插画带来“复古游戏”的趣味感。
*   **内容优先**：极简的边框和卡片设计，让数据和代码成为主角。
*   **层次感**：通过微妙的边框颜色（Border Colors）而非阴影（Shadows）来区分层级。

---

## 2. 颜色系统 (Color Palette)

MotherDuck 的配色方案非常克制。背景以深灰/黑为主，主色调为标志性的“鸭子黄”，辅助色用于代码高亮。

### CSS Variables 定义

```css
:root {
  /* --- 基础背景 --- */
  --bg-primary: #0F0F0F;    /* 接近纯黑的主背景 */
  --bg-secondary: #1A1A1A;  /* 卡片或侧边栏背景 */
  --bg-tertiary: #262626;   /* 输入框或悬停状态 */

  /* --- 强调色 (Brand Colors) --- */
  --accent-yellow: #FFE600; /* MotherDuck 标志性黄色 */
  --accent-yellow-hover: #E6CF00;

  /* --- 文字颜色 --- */
  --text-primary: #FFFFFF;  /* 标题 */
  --text-secondary: #A3A3A3; /* 正文/说明文字 */
  --text-tertiary: #525252;  /* 禁用或极淡的提示 */

  /* --- 边框系统 --- */
  --border-subtle: #333333; /* 常规分割线 */
  --border-active: #555555; /* 悬停或聚焦时的边框 */
}
```

---

## 3. 排版系统 (Typography)

字体通常选用现代、几何感强的无衬线字体（Sans-serif），配合等宽字体（Monospace）用于显示代码和数据。

*   **Primary Font**: `Inter`, `Roobert`, or `system-ui`.
*   **Code Font**: `JetBrains Mono`, `Fira Code`.

### 样式特征
*   **Headings**: 字重较大 (Bold/ExtraBold)，字间距（Tracking）略微收紧。
*   **Body**: 字号适中 (16px)，行高宽松 (1.6)，确保阅读舒适度。

```css
body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  background-color: var(--bg-primary);
  color: var(--text-primary);
  line-height: 1.6;
}

h1, h2, h3 {
  font-weight: 700;
  letter-spacing: -0.02em; /* 略微收紧，增加现代感 */
  margin-bottom: 1rem;
}

code, pre {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.9em;
}
```

---

## 4. 组件设计 (Component Design)

### A. 按钮 (Buttons)

MotherDuck 的按钮风格非常鲜明：
1.  **Primary Button**: 高亮黄色背景，黑色文字，直角或微圆角（4px），类似工业标签。
2.  **Secondary Button**: 透明背景，白色边框，悬停变亮。

```css
/* 基础按钮样式 */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0.75rem 1.5rem;
  font-weight: 600;
  font-size: 1rem;
  border-radius: 6px; /* 微圆角 */
  transition: all 0.2s ease;
  cursor: pointer;
  text-decoration: none;
}

/* 主按钮：黄色实心 */
.btn-primary {
  background-color: var(--accent-yellow);
  color: #000000;
  border: 1px solid var(--accent-yellow);
}

.btn-primary:hover {
  background-color: var(--accent-yellow-hover);
  transform: translateY(-1px); /* 轻微上浮 */
}

/* 次级按钮：描边风格 */
.btn-secondary {
  background-color: transparent;
  color: var(--text-primary);
  border: 1px solid var(--border-subtle);
}

.btn-secondary:hover {
  border-color: var(--text-primary);
  background-color: rgba(255, 255, 255, 0.05);
}
```

### B. 卡片 (Cards & Containers)

布局常采用 **Bento Grid（便当盒网格）** 风格。卡片没有明显的阴影，而是依靠背景色差和边框来界定。

*   **Background**: `--bg-secondary` (#1A1A1A)
*   **Border**: 1px solid `--border-subtle`
*   **Padding**: 宽松 (24px - 32px)

```css
.card {
  background-color: var(--bg-secondary);
  border: 1px solid var(--border-subtle);
  border-radius: 12px; /* 较大的圆角，显得柔和 */
  padding: 2rem;
  position: relative;
  overflow: hidden;
  transition: border-color 0.3s ease;
}

.card:hover {
  border-color: var(--border-active);
}

/* MotherDuck 特色：卡片内的标签 */
.tag {
  background-color: rgba(255, 230, 0, 0.1);
  color: var(--accent-yellow);
  padding: 4px 8px;
  border-radius: 4px;
  font-family: monospace;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
```

### C. 数据展示/表格 (Data Tables)

由于 MotherDuck 是数据库产品，数据展示风格至关重要。通常表现为“终端（Terminal）”风格。

```css
.terminal-window {
  background-color: #000;
  border: 1px solid #333;
  border-radius: 8px;
  font-family: 'JetBrains Mono', monospace;
  padding: 1rem;
}

.terminal-header {
  display: flex;
  gap: 6px;
  margin-bottom: 1rem;
}

.dot { width: 10px; height: 10px; border-radius: 50%; background: #333; }

.sql-query {
  color: var(--accent-yellow);
  margin-bottom: 1rem;
}

.query-result {
  color: var(--text-secondary);
  font-size: 0.875rem;
}
```

---

## 5. 布局与空间 (Layout & Spacing)

风格核心：**呼吸感 (Breathing Room)**。不要让元素拥挤。

*   **Container Max-Width**: 1200px (在大屏上居中)
*   **Section Spacing**: 垂直间距通常很大 (80px - 120px)

```css
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 24px;
}

.section {
  padding: 100px 0; /* 大垂直间距 */
  border-bottom: 1px solid var(--border-subtle); /* 区块间常用细线分割 */
}

.grid-3 {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 24px;
}
```

---

## 6. 特殊视觉元素 (Visual Assets)

这是“画龙点睛”的部分，若缺少这些，网站会显得像普通的 SaaS 模板。

1.  **像素艺术 (Pixel Art)**:
    *   在标题旁或卡片角落使用像素化的图标（如像素鸭子、数据库图标）。
    *   *实现建议*: 使用 SVG 绘制矩形网格，或直接使用 PNG 像素图。

2.  **网格背景 (Grid Background)**:
    *   背景通常不是纯黑，而是带有一层极淡的网格线，增加科技感。

```css
.grid-bg {
  background-color: var(--bg-primary);
  background-image:
    linear-gradient(var(--border-subtle) 1px, transparent 1px),
    linear-gradient(90deg, var(--border-subtle) 1px, transparent 1px);
  background-size: 40px 40px; /* 网格大小 */
  background-position: center top;
  /* 让网格非常淡，仅作为纹理 */
  opacity: 0.1;
}
```

---

## 7. 完整 HTML/CSS 结构示例 (Minimal Example)

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MotherDuck Style Example</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;900&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400&display=swap" rel="stylesheet">
<style>
  :root {
    --bg-primary: #0F0F0F;
    --bg-secondary: #1A1A1A;
    --accent-yellow: #FFE600;
    --accent-yellow-hover: #E6CF00;
    --text-primary: #FFFFFF;
    --text-secondary: #A3A3A3;
    --border-subtle: #333333;
    --border-active: #555555;
  }

  body {
    margin: 0;
    background-color: var(--bg-primary);
    color: var(--text-primary);
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
    line-height: 1.6;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  /* Grid Background Overlay - Optional, can be applied to a specific div or body */
  .grid-bg {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: var(--bg-primary);
    background-image:
      linear-gradient(var(--border-subtle) 1px, transparent 1px),
      linear-gradient(90deg, var(--border-subtle) 1px, transparent 1px);
    background-size: 40px 40px;
    background-position: center top;
    opacity: 0.1;
    z-index: -1; /* Ensure it stays behind content */
  }

  nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 20px 40px;
    border-bottom: 1px solid var(--border-subtle);
    backdrop-filter: blur(10px);
    background-color: rgba(15, 15, 15, 0.8); /* Semi-transparent for blur effect */
    position: sticky;
    top: 0;
    z-index: 100;
  }

  .logo {
    font-weight: 900;
    font-size: 1.2rem;
    display: flex;
    align-items: center;
    gap: 10px;
    color: var(--text-primary);
    text-decoration: none;
  }
  .logo-icon {
    width: 24px;
    height: 24px;
    background: var(--accent-yellow); /* Simple block to simulate pixel art icon */
    transform: rotate(45deg); /* A little playful touch */
  }

  nav a {
    color: var(--text-secondary);
    text-decoration: none;
    margin-left: 20px;
    transition: color 0.2s ease;
  }
  nav a:hover {
    color: var(--text-primary);
  }

  .hero {
    max-width: 1000px;
    margin: 0 auto;
    text-align: center;
    padding: 120px 20px;
  }

  h1 {
    font-size: clamp(2.5rem, 5vw, 4rem); /* Responsive font size */
    line-height: 1.1;
    margin-bottom: 24px;
    letter-spacing: -0.03em;
  }

  .highlight {
    color: var(--accent-yellow);
  }

  p.subtitle {
    font-size: clamp(1rem, 2vw, 1.25rem);
    color: var(--text-secondary);
    max-width: 600px;
    margin: 0 auto 40px auto;
  }

  .actions {
    display: flex;
    gap: 16px;
    justify-content: center;
    flex-wrap: wrap; /* Allow buttons to wrap on small screens */
  }

  .btn {
    padding: 12px 24px;
    border-radius: 6px;
    font-weight: 600;
    text-decoration: none;
    transition: all 0.2s ease;
    white-space: nowrap; /* Prevent text wrapping inside buttons */
  }

  .btn-primary {
    background: var(--accent-yellow);
    color: black;
    border: 1px solid var(--accent-yellow);
  }
  .btn-primary:hover {
    background: var(--accent-yellow-hover);
    border-color: var(--accent-yellow-hover);
    transform: translateY(-2px);
    box-shadow: 0 4px 8px rgba(0,0,0,0.2);
  }

  .btn-secondary {
    background: transparent;
    color: var(--text-primary);
    border: 1px solid var(--border-subtle);
  }
  .btn-secondary:hover {
    border-color: var(--text-primary);
    background-color: rgba(255, 255, 255, 0.05);
    transform: translateY(-2px);
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  }

  .code-preview {
    margin-top: 60px;
    background: #000;
    border: 1px solid var(--border-subtle);
    border-radius: 12px;
    padding: 24px;
    text-align: left;
    box-shadow: 0 20px 50px rgba(0,0,0,0.5);
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.9em;
    overflow-x: auto; /* Allow horizontal scrolling for long code lines */
  }

  .sql-kw { color: #ff79c6; } /* Example syntax highlighting color */
  .sql-str { color: var(--accent-yellow); }
  .sql-comment { color: #666; margin-top: 10px; display: block; } /* display: block for new line */

  .section {
    padding: 100px 0;
    border-bottom: 1px solid var(--border-subtle);
  }
  .section:last-of-type {
    border-bottom: none; /* No border for the last section */
  }

  .container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 0 24px;
  }

  h2 {
    font-size: clamp(2rem, 4vw, 3rem);
    text-align: center;
    margin-bottom: 60px;
  }

  .grid-3 {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 30px;
  }

  .card {
    background-color: var(--bg-secondary);
    border: 1px solid var(--border-subtle);
    border-radius: 12px;
    padding: 2rem;
    position: relative;
    overflow: hidden;
    transition: border-color 0.3s ease, transform 0.2s ease;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }

  .card:hover {
    border-color: var(--border-active);
    transform: translateY(-5px);
  }

  .card h3 {
    font-size: 1.5rem;
    color: var(--text-primary);
    margin-top: 0;
    margin-bottom: 1rem;
  }

  .card p {
    color: var(--text-secondary);
    font-size: 0.95rem;
    flex-grow: 1; /* Allow paragraph to take available space */
  }

  .tag {
    background-color: rgba(255, 230, 0, 0.1);
    color: var(--accent-yellow);
    padding: 4px 8px;
    border-radius: 4px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 0.75rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    align-self: flex-start; /* Align tag to the start within flex column */
    margin-top: 1rem;
  }

  footer {
    text-align: center;
    padding: 40px 20px;
    color: var(--text-secondary);
    font-size: 0.9rem;
    border-top: 1px solid var(--border-subtle);
    margin-top: 60px;
  }

  /* Responsive adjustments */
  @media (max-width: 768px) {
    nav {
      padding: 15px 20px;
    }
    .hero {
      padding: 80px 20px;
    }
    h1 {
      font-size: 2.5rem;
    }
    p.subtitle {
      font-size: 1rem;
    }
    .actions {
      flex-direction: column;
      gap: 10px;
    }
    .btn {
      width: 100%;
    }
    .section {
      padding: 60px 0;
    }
    h2 {
      font-size: 2rem;
      margin-bottom: 40px;
    }
  }
</style>
</head>
<body>

<div class="grid-bg"></div>

<nav>
  <a href="#" class="logo">
    <div class="logo-icon"></div> MotherDuck
  </a>
  <div>
    <a href="#">Docs</a>
    <a href="#">Blog</a>
    <a href="#">Login</a>
  </div>
</nav>

<section class="hero">
  <h1>Serverless DuckDB<br>for <span class="highlight">Data Analytics</span></h1>
  <p class="subtitle">
    Analyze data of any size with the power of DuckDB, optimized for the cloud. No infrastructure to manage.
  </p>

  <div class="actions">
    <a href="#" class="btn btn-primary">Get Started</a>
    <a href="#" class="btn btn-secondary">Read the Docs</a>
  </div>

  <div class="code-preview">
    <div><span class="sql-kw">SELECT</span> count(*) <span class="sql-kw">FROM</span> service_requests</div>
    <div><span class="sql-kw">WHERE</span> status = <span class="sql-str">'completed'</span>;</div>
    <span class="sql-comment">-- Result: 14,029,302 rows in 0.04s</span>
  </div>
</section>

<section class="section">
  <div class="container">
    <h2>Powerful Features at Your Fingertips</h2>
    <div class="grid-3">
      <div class="card">
        <h3>Fast Query Execution</h3>
        <p>Leverage DuckDB's in-process analytical database for lightning-fast query performance directly in your browser or serverless environment.</p>
        <span class="tag">Performance</span>
      </div>
      <div class="card">
        <h3>Zero-Ops Simplicity</h3>
        <p>Focus on your data, not your infrastructure. MotherDuck handles all the scaling, patching, and maintenance for you.</p>
        <span class="tag">Serverless</span>
      </div>
      <div class="card">
        <h3>Seamless Data Integration</h3>
        <p>Connect with your existing data sources, from S3 to local files, and query them effortlessly with SQL.</p>
        <span class="tag">Integration</span>
      </div>
    </div>
  </div>
</section>

<footer>
  <p>&copy; 2025 MotherDuck. All rights reserved.</p>
</footer>

</body>
</html>
