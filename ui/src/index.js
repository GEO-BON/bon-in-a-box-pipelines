import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import reportWebVitals from './reportWebVitals';
import {
  BrowserRouter,
  Routes,
  Route,
} from "react-router-dom";

import { SingleScriptPage } from "./components/SingleScriptPage";
import { PipelinePage } from "./components/PipelinePage";
import { PipelineEditor } from "./components/PipelineEditor/PipelineEditor";
import ScriptChooser from "./components/PipelineEditor/ScriptChooser";
import { Layout } from './Layout.js';

ReactDOM.render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<Layout />} />

      <Route path="script-form" element={
        <Layout right={<SingleScriptPage />} />
      } />

      <Route path="pipeline-form" element={
      <Layout right={<PipelinePage />} />
      } />

      <Route path="pipeline-editor" element={
        <Layout left={<ScriptChooser />}
          right={<PipelineEditor />} />
      } />

      <Route path="*" element={
        <main style={{ padding: "1rem" }}>
          <h2>404 - Page not found</h2>
          <p>Lost in the wilderness?</p>
        </main>
      } />

    </Routes>
  </BrowserRouter>,
  document.getElementById('root')
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
