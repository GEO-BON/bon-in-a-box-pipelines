import React, { useState, useRef, useEffect } from 'react';
import { useInterval } from '../UseInterval';
import { isVisible } from '../utils/isVisible';

export function LogViewer({ address, autoUpdate }) {
  const [logs, setLogs] = useState("");
  const [logsAutoScroll, setLogsAutoScroll] = useState(true);
  const logsRef = useRef();
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
        if(response.status != 404) { // 404 error can be normal if script has no logs.
          setLogs(logs + "\n" + response.status + " (" + response.statusText + ")");
        }
      });

  }

  // First and last fetch
  useEffect(() => fetchLogs(), [autoUpdate])
  // Auto-update
  const interval = useInterval(() => {
    fetchLogs(interval)
  }, autoUpdate ? 1000 : null);

  // Logs auto-scrolling
  useEffect(() => {
    if (logsAutoScroll) {
      let logsElem = logsRef.current
      if(logsElem) {
        logsElem.scroll({ top: logsElem.scrollHeight });
      }
    }
  }, [logs, logsAutoScroll]);

  return logs && <pre ref={logsRef} className='logs'>{logs}<span ref={logsEndRef} /></pre>;
}
