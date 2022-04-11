import './Layout.css';

import React, { useEffect, useState } from 'react'

import { NavLink } from "react-router-dom";

import BiaBLogo from "./img/boninabox.jpg"

import useWindowDimensions from "./states/WindowDimensions"

export function Layout(props) {
  const { windowHeight } = useWindowDimensions();
  const [mainHeight, setMainHeight] = useState();

  // Main section size
  useEffect(() => {
    let header = document.getElementsByTagName('header')[0];
    let nav = document.getElementsByTagName('nav')[0];
    setMainHeight(windowHeight - nav.offsetHeight)
  }, [windowHeight])

  return (
    <>
      <div className="left-banner">
        <img id="logo" src={BiaBLogo} alt="BON in a Box logo" />
        {props.left}
      </div>

      <div className='right-content'>
        <nav>
          <NavLink to="/script-form">Single script run</NavLink>
          &nbsp;|&nbsp;
          <NavLink to="/pipeline-form">Pipeline run</NavLink>
          &nbsp;|&nbsp;
          <NavLink to="/pipeline-editor">Pipeline editor</NavLink>
        </nav>

        <main style={{height: mainHeight}}>
          {props.right}
        </main>
      </div>
    </>
  );
}
