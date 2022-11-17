import React, { useRef, useEffect, useContext, useState } from 'react';

export const RenderContext = React.createContext();

export function createContext(activeRenderer, setActiveRenderer) {
    return { 
        active: activeRenderer,
        toggleVisibility: (componentId) => setActiveRenderer(activeRenderer === componentId ? null : componentId)
    }
}

export function FoldableOutputWithContext(props) {
    const renderContext = useContext(RenderContext);
    let active = renderContext.active === props.componentId;
    const titleRef = useRef(null);

    useEffect(() => {
        if (active) {
            titleRef.current.scrollIntoView({ block: 'start', behavior: 'smooth' });
        }
    }, [active]);

    return <div className={props.className}>
        <div className="outputTitle">
            <h3 ref={titleRef} onClick={() => renderContext.toggleVisibility(props.componentId)} className="clickable">
                {active ? <b>–</b> : <b>+</b>} {props.title}
            </h3>
            {props.inline}
            {!active && props.inlineCollapsed}
        </div>
        {active &&
            <div className="outputContent">
                {props.description && <p className="outputDescription">{props.description}</p>}
                {props.children}
            </div>}
    </div>;
}

export function FoldableOutput(props) {
    const [active, setActive] = useState(false)
    const titleRef = useRef(null);

    useEffect(() => {
        if (active) {
            titleRef.current.scrollIntoView({ block: 'start', behavior: 'smooth' });
        }
    }, [active]);

    return <div className={props.className}>
        <div className="outputTitle">
            <h3 ref={titleRef} onClick={() => setActive(prev => !prev)} className="clickable">
                {active ? <b>–</b> : <b>+</b>} {props.title}
            </h3>
            {props.inline}
            {!active && props.inlineCollapsed}
        </div>
        {active &&
            <div className="outputContent">
                {props.description && <p className="outputDescription">{props.description}</p>}
                {props.children}
            </div>}
    </div>
}
