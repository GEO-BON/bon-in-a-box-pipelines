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
    setMainHeight(windowHeight - nav.offsetHeight)
  }, [windowHeight])

  return (
    <>
      <div className="left-pane">
        <div>
          <img id="logo" src={BiaBLogo} alt="BON in a Box logo" />
        </div>
        {props.left}
      </div>

      <div className='right-content'>
        <nav>
          <NavLink to="/script-form">Single script run</NavLink>
          &nbsp;|&nbsp;
          <NavLink to="/pipeline-form">Pipeline run</NavLink>
          &nbsp;|&nbsp;
          <NavLink to="/pipeline-editor">Pipeline editor</NavLink>
          &nbsp;|&nbsp;
          <a href="api/versions" target="_blank">Server info</a>
        </nav>

        {props.popupContent && 
          <div className='fullScreenPopup'>
            <div className='content'>
              {props.popupContent}
            </div>
            <button title="Close" className='close' onClick={() => props.setPopupContent(null)}>×</button>
          </div>
        }

        <main style={{height: mainHeight}}>
          {props.right}
        </main>
      </div>
    </>
  );
}
