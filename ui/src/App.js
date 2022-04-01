import './App.css';

import React from 'react'

import { Outlet, NavLink } from "react-router-dom";

function App() {

  return (
    <>
      <header className="App-header">
        <h1>BON in a Box v2 pre-pre alpha</h1>
      </header>

      <nav>
        <NavLink to="/script-form">Single script run</NavLink>
        &nbsp;|&nbsp;
        <NavLink to="/pipeline-form">Pipeline run</NavLink>
        &nbsp;|&nbsp;
        <NavLink to="/pipeline-editor">Pipeline editor</NavLink>
      </nav>

      <main>
        <Outlet />
      </main>
    </>
  );
}

export default App
