import React, { useRef, useEffect, useContext, useState } from 'react';

export const RenderContext = React.createContext();

export function createContext(activeRenderer, setActiveRenderer) {
    return { 
        active: activeRenderer,
        toggleVisibility: (componentId) => setActiveRenderer(activeRenderer === componentId ? null : componentId)
    }
}

export function FoldableOutputWithContext({className, title, componentId, inline, inlineCollapsed, children}) {
    const renderContext = useContext(RenderContext);
    let active = renderContext.active === componentId;

    return <FoldableOutputInternal toggle={() => renderContext.toggleVisibility(componentId)} active={active}
        className={className} title={title} inline={inline} inlineCollapsed={inlineCollapsed} children={children} />
}

export function FoldableOutput({className, title, inline, inlineCollapsed, children}) {
    const [active, setActive] = useState(false)

    return <FoldableOutputInternal toggle={() => setActive(prev => !prev)} active={active}
        className={className} title={title} inline={inline} inlineCollapsed={inlineCollapsed} children={children} />
}

function FoldableOutputInternal({toggle, active, className, title, inline, inlineCollapsed, children}) {
    const titleRef = useRef(null);

    useEffect(() => {
        if (active) {
            titleRef.current.scrollIntoView({ block: 'start', behavior: 'smooth' });
        }
    }, [active]);

    return <div className={className}>
        <div className="outputTitle">
            <h3 ref={titleRef} onClick={toggle} className="clickable">
                {active ? <b>–</b> : <b>+</b>} {title}
            </h3>
            {inline}
            {!active && inlineCollapsed}
        </div>
        {active &&
            <div className="outputContent">
                {children}
            </div>}
    </div>
}
