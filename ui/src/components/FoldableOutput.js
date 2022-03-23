import React, { useRef, useEffect, useContext } from 'react';

export const RenderContext = React.createContext();

export function createContext(activeRenderer, toggleVisibility) {
    return { active: activeRenderer, toggleVisibility: toggleVisibility }
}

export function FoldableOutput(props) {
    const renderContext = useContext(RenderContext);
    let active = renderContext.active === props.componentId;
    const titleRef = useRef(null);

    useEffect(() => {
        if (active) {
            titleRef.current.scrollIntoView({ block: 'start', behavior: 'smooth' });
        }
    }, [active]);

    return <>
        <div className="outputTitle">
            <h3 ref={titleRef} onClick={() => renderContext.toggleVisibility(props.componentId)} className="clickable">
                {active ? <b>–</b> : <b>+</b>} {props.title}
            </h3>
            {props.inline && (
                isRelativeLink(props.inline) ? (
                    active && props.inline && <a href={props.inline} target="_blank" rel="noreferrer">{props.inline}</a>
                ) : (
                    !active && props.inline
                )
            )}

        </div>
        {active &&
            <div className="outputContent">
                {props.description && <p className="outputDescription">{props.description}</p>}
                {props.children}
            </div>}
    </>;
}

export function isRelativeLink(value) {
    if (typeof value.startsWith === "function") { 
        return value.startsWith('/')
    }
    return false
}
