import React, { useState, useRef, useEffect } from 'react';
import { useInterval } from '../UseInterval';
import { isVisible } from '../utils/IsVisible';

export function LogViewer({ address, autoUpdate }) {
  const [logs, setLogs] = useState("");
  const [logsAutoScroll, setLogsAutoScroll] = useState(true);
  const logsEndRef = useRef();

  function fetchLogs(intervalRef) {
    // Fetch the logs
    let start = new Blob([logs]).size;
    fetch(address, {
      headers: { 'range': `bytes=${start}-` },
    })
      .then(response => {
        if (response.ok) {
          return response.text();
        } else if (response.status === 416) { // Range not satifiable
          return Promise.resolve(null); // Wait for next try
        } else {
          return Promise.reject(response);
        }
      })
      .then(responseText => {
        if (responseText) {

          if (logsEndRef.current) {
            let visible = isVisible(logsEndRef.current, logsEndRef.current.parentNode);
            setLogsAutoScroll(visible);
          }

          setLogs(logs + responseText);
        }
      })
      .catch(response => {
        if(intervalRef) clearInterval(intervalRef);
        setLogs(logs + "\n" + response.status + " (" + response.statusText + ")");
      });

  }

  // First fetch
  useEffect(() => fetchLogs(), [address])
  // Auto-update
  const interval = useInterval(() => {
    fetchLogs(interval)
  }, autoUpdate ? 1000 : null);

  // Logs auto-scrolling
  useEffect(() => {
    if (logsAutoScroll && logsEndRef.current) {
      logsEndRef.current.scrollIntoView({ block: 'end' });
    }
  }, [logs, logsAutoScroll]);

  return <pre className='logs'>{logs}<span ref={logsEndRef} /></pre>;
}