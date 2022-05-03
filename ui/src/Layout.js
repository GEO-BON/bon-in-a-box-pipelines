import './Layout.css';

import React, { useEffect, useState } from 'react'

import { NavLink } from "react-router-dom";

import BiaBLogo from "./img/boninabox.jpg"

import useWindowDimensions from "./utils/WindowDimensions"

export function Layout(props) {
  const { windowHeight } = useWindowDimensions();
  const [mainHeight, setMainHeight] = useState();

  // Main section size
  useEffect(() => {
    let nav = document.getElementsByTagName('nav')[0];
    console.log("nav height="+nav.offsetHeight)
    setMainHeight(windowHeight - nav.offsetHeight)
  }, [windowHeight])

  return (
    <>
      <div className="left-pane">
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
