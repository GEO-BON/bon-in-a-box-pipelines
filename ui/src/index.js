import React, {useState} from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import reportWebVitals from './reportWebVitals';
import {
  BrowserRouter,
  Routes,
  Route,
  useLocation,
} from "react-router-dom";

import { SingleScriptPage } from "./components/SingleScriptPage";
import { PipelinePage } from "./components/PipelinePage";
import { PipelineEditor } from "./components/PipelineEditor/PipelineEditor";
import ScriptChooser from "./components/PipelineEditor/ScriptChooser";
import { Layout } from './Layout.js';

function NotFound() {
  const location = useLocation()
  return <main style={{ padding: "1rem" }}>
    <h2>404 - Page not found</h2>
    <p>{location.pathname}</p>
    <p>Lost in the wilderness?</p>
  </main>
}

function App() {
  const [popupContent, setPopupContent] = useState();

  return <BrowserRouter>
    <Routes>
      <Route path="/" element={<Layout />} />

      <Route path="script-form" element={
        <Layout right={<SingleScriptPage />} />
      } />
      
      <Route path="pipeline-form" element={
      <Layout right={<PipelinePage />} />
      } />

      <Route path="pipeline-form/:pipelineRunId/" element={
      <Layout right={<PipelinePage />} />
      } />

      <Route path="pipeline-editor" element={
        <Layout left={<ScriptChooser popupContent={popupContent} setPopupContent={setPopupContent} />}
          right={<PipelineEditor />}
          popupContent={popupContent}
          setPopupContent={setPopupContent} />
      } />

      <Route path="*" element={
        <Layout left={<ScriptChooser />}
          right={<NotFound />} />
      } />

    </Routes>
  </BrowserRouter>
}

const root = createRoot(document.getElementById('root'));
root.render(<App />);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
