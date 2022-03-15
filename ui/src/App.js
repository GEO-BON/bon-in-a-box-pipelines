import './App.css';

import React from 'react'

import { Outlet, NavLink } from "react-router-dom";

function App() {

  function getLinkStyle( isActive ) {
    return {
       color: isActive ? "white" : "",
       "text-decoration": isActive ? "none" : "underline"
       };
  }

  return (
    <>
      <header className="App-header">
        <h1>BON in a Box v2 pre-pre-pre alpha</h1>
      </header>

      <nav>
        <NavLink to="/script-form" style={({ isActive }) => getLinkStyle(isActive)}>Single script</NavLink> | <NavLink to="/pipeline-form">Pipeline</NavLink>
      </nav>

      <main>
        <Outlet />
      </main>
    </>
  );
}

export default App
