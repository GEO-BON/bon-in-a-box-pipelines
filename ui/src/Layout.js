import './Layout.css';

import React from 'react'

import { NavLink } from "react-router-dom";

import BiaBLogo from "./img/boninabox.jpg"

export function Layout(props) {

  return (
    <>
      <div className="left-banner">
        <img id="logo" src={BiaBLogo} alt="BON in a Box logo" />
        {props.left}
      </div>

      <div className='right-content'>
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
          {props.right}
        </main>
      </div>
    </>
  );
}
