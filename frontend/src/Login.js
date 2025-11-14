import React, { useState } from 'react';
import './Login.css';

function Login({ onLogin }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');

  // 写死的用户名和密码
  const VALID_USERNAME = 'admin';
  const VALID_PASSWORD = '123456';

  const handleSubmit = (e) => {
    e.preventDefault();
    
    if (username === VALID_USERNAME && password === VALID_PASSWORD) {
      onLogin(true);
    } else {
      setError('用户名或密码错误');
    }
  };

  return (
    <div className="login-container">
      <div className="login-box">
        <h2>🎤 语音转录系统</h2>
        <p className="login-subtitle">请登录以使用服务</p>
        
        <form onSubmit={handleSubmit} className="login-form">
          <div className="form-group">
            <label>用户名</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              placeholder="请输入用户名"
              required
            />
          </div>
          
          <div className="form-group">
            <label>密码</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="请输入密码"
              required
            />
          </div>
          
          {error && <div className="error-message">{error}</div>}
          
          <button type="submit" className="login-button">
            登录
          </button>
        </form>
        
        <div className="login-hint">
          <p>提示: admin / 123456</p>
        </div>
      </div>
    </div>
  );
}

export default Login;
