/**
 * 
 * @param x screenX to display the menu
 * @param y screenY to display the menu
 * @param optionMapping object who's properties map string to function
 */
export default function PopupMenu({ x, y, optionMapping, onPopupMenuHide }) {
    return optionMapping && x && y &&
        <ul id='popupMenu' style={{
            '--mouse-x': x + 'px',
            '--mouse-y': y + 'px',
        }}>
            {Object.entries(optionMapping).map((entry, i) => {
                const [key, value] = entry;
                return <li key={i} onClick={() => { onPopupMenuHide(); value() }}>{key}</li>
            })}
        </ul>
}